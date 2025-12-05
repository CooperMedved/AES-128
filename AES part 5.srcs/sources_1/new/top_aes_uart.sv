`timescale 1ns/1ps

module top_uart_aes (
    input  logic CLK100MHZ,   // 100 MHz board clock
    input  logic UART_RX,     // FTDI TX -> FPGA RX
    output logic UART_TX,     // FPGA TX -> FTDI RX
    input  logic BTNC         // optional button (can ignore)
);

  // ============================================================
  // UART PARAMETERS
  // ============================================================
  localparam int unsigned CLKS_PER_BIT = 868;   // 100 MHz / 115200

  // ============================================================
  // UART RX
  // ============================================================
  logic       rx_dv;
  logic [7:0] rx_byte;

  uart_rx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) U_RX (
    .clk       (CLK100MHZ),
    .rx_serial (UART_RX),
    .o_rx_dv   (rx_dv),
    .o_rx_byte (rx_byte)
  );

  // ============================================================
  // UART TX
  // ============================================================
  logic       tx_dv;
  logic [7:0] tx_byte;
  logic       tx_act;
  logic       tx_done;

  uart_tx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) U_TX (
    .clk       (CLK100MHZ),
    .tx_dv     (tx_dv),
    .tx_byte   (tx_byte),
    .o_tx_act  (tx_act),
    .o_tx_ser  (UART_TX),
    .o_tx_done (tx_done)
  );

  // ============================================================
  // (Optional) BUTTON SYNC (not required for basic use)
  // ============================================================
  logic b1 = 1'b0, b2 = 1'b0;
  always_ff @(posedge CLK100MHZ) begin
    b1 <= BTNC;
    b2 <= b1;
  end
  wire btn_rise = b2 & ~b1;   // 1-cycle pulse on button edge

  // ============================================================
  // TX FSM TYPE & REG DECL
  // ============================================================
  typedef enum logic [1:0] {
    T_IDLE,
    T_SEND,
    T_WAIT
  } tx_state_t;

  tx_state_t tx_state = T_IDLE;
  logic [5:0] out_idx = '0;   // 0..33 (32 hex chars + CR + LF)

  // ============================================================
  // PLAINTEXT CAPTURE AS ASCII HEX
  //
  // - You type 32 hex chars: 0..9, A..F, a..f
  // - CR/LF (Enter) are ignored
  // - Each pair of hex chars -> one byte in pt_bytes[]
  // - After 32 nibbles, we assert pt_ready = 1 and have a 128-bit block
  // ============================================================
  logic [7:0]  pt_bytes [0:15];    // 16 bytes plaintext
  logic [5:0]  hex_count = '0;     // counts 0..31 nibbles
  logic        pt_ready  = 1'b0;   // one full 128-bit block assembled

  // AES control
  logic        aes_start = 1'b0;
  logic        aes_done;
  logic        aes_busy  = 1'b0;

  logic [127:0] plaintext;
  logic [127:0] ciphertext;

  // Pack pt_bytes into 128-bit plaintext, MSB-first:
  // plaintext = { pt_bytes[0], pt_bytes[1], ..., pt_bytes[15] }
  always_comb begin
    plaintext = '0;
    for (int i = 0; i < 16; i++) begin
      plaintext[127 - 8*i -: 8] = pt_bytes[i];
    end
  end

  // Hex capture + AES busy bookkeeping
  always_ff @(posedge CLK100MHZ) begin
    // ----------------------------------------------------
    // Collect 32 hex nibbles when AES is not busy and
    // the current block is not yet marked ready.
    // ----------------------------------------------------
    if (rx_dv && !aes_busy && !pt_ready) begin
      logic [3:0] nibble;
      logic       nib_valid;

      nibble    = 4'h0;
      nib_valid = 1'b0;

      // Ignore CR/LF (Enter)
      if (rx_byte == 8'h0D || rx_byte == 8'h0A) begin
        // nothing
      end
      else begin
        // classify ASCII hex
        if (rx_byte >= "0" && rx_byte <= "9") begin
          nibble    = rx_byte - "0";
          nib_valid = 1'b1;
        end
        else if (rx_byte >= "A" && rx_byte <= "F") begin
          nibble    = rx_byte - "A" + 4'd10;
          nib_valid = 1'b1;
        end
        else if (rx_byte >= "a" && rx_byte <= "f") begin
          nibble    = rx_byte - "a" + 4'd10;
          nib_valid = 1'b1;
        end

        if (nib_valid) begin
          // which byte are we filling? (0..15)
          logic [3:0] byte_idx;
          byte_idx = hex_count[5:1];     // hex_count / 2

          if (hex_count[0] == 1'b0) begin
            // even nibble index -> high nibble of byte
            pt_bytes[byte_idx][7:4] <= nibble;
          end
          else begin
            // odd nibble index -> low nibble of byte
            pt_bytes[byte_idx][3:0] <= nibble;
          end

          // advance nibble counter
          if (hex_count == 6'd31) begin
            hex_count <= 6'd0;
            pt_ready  <= 1'b1;   // full 128-bit block ready
          end
          else begin
            hex_count <= hex_count + 6'd1;
          end
        end
      end
    end

    // Optional: button can also mark block as ready (rarely needed)
    if (btn_rise && !aes_busy) begin
      pt_ready <= 1'b1;
    end

    // once AES actually starts, clear pt_ready and mark busy
    if (aes_start) begin
      pt_ready <= 1'b0;
      aes_busy <= 1'b1;
    end

    // when AES finishes, clear busy
    if (aes_done) begin
      aes_busy <= 1'b0;
    end
  end

  // ============================================================
  // AES-128 CORE
  // ============================================================
  localparam logic [127:0] AES_KEY =
    128'h000102030405060708090A0B0C0D0E0F;

  aes128_core AES (
    .clk   (CLK100MHZ),
    .rst_n (1'b1),
    .start (aes_start),
    .key   (AES_KEY),
    .pt    (plaintext),
    .ct    (ciphertext),
    .done  (aes_done)
  );

  // ============================================================
  // AES START LOGIC
  // Only start when:
  //   - full block captured (pt_ready)
  //   - TX is idle (no active transmit)
  //   - TX FSM is in T_IDLE
  // ============================================================
  always_ff @(posedge CLK100MHZ) begin
    aes_start <= 1'b0;   // default

    if (pt_ready && !tx_act && tx_state == T_IDLE) begin
      aes_start <= 1'b1; // one-cycle pulse
    end
  end

  // ============================================================
  // CT (ciphertext) TO ASCII HEX CONVERTER
  // ============================================================
  function automatic logic [7:0] nibble_to_ascii (input logic [3:0] n);
    if (n < 10) nibble_to_ascii = "0" + n;
    else        nibble_to_ascii = "A" + (n - 10);
  endfunction

  logic [7:0] hex_out [0:31];
  logic [3:0] nib;

  always_comb begin
    for (int i = 0; i < 32; i++) begin
      nib        = ciphertext[127 - i*4 -: 4];
      hex_out[i] = nibble_to_ascii(nib);
    end
  end

  // ============================================================
  // TX FSM - send 32 hex chars + CR + LF
  // ============================================================
  always_ff @(posedge CLK100MHZ) begin
    tx_dv <= 1'b0;  // default

    unique case (tx_state)

      T_IDLE: begin
        // Wait for AES done, then start sending
        if (aes_done && !tx_act) begin
          out_idx  <= 6'd0;
          tx_state <= T_SEND;
        end
      end

      T_SEND: begin
        if (!tx_act) begin
          if (out_idx < 32)
            tx_byte <= hex_out[out_idx];
          else if (out_idx == 32)
            tx_byte <= 8'h0D;    // CR
          else
            tx_byte <= 8'h0A;    // LF

          tx_dv    <= 1'b1;
          tx_state <= T_WAIT;
        end
      end

      T_WAIT: begin
        if (tx_done) begin
          if (out_idx == 33) begin
            tx_state <= T_IDLE;  // done sending
          end
          else begin
            out_idx  <= out_idx + 6'd1;
            tx_state <= T_SEND;
          end
        end
      end

      default: tx_state <= T_IDLE;
    endcase
  end

endmodule
