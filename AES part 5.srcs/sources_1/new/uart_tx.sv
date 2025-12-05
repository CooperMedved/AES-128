`timescale 1ns / 1ps

module uart_tx #(
  parameter int unsigned CLKS_PER_BIT = 868
)(
  input  logic       clk,
  input  logic       tx_dv,       // 1-cycle start pulse 
  input  logic [7:0] tx_byte,
  output logic       o_tx_act,    // high while transmitting
  output logic       o_tx_ser,    // UART TX line
  output logic       o_tx_done    // 1-cycle pulse when frame completes
);

  typedef enum logic [2:0] { IDLE, TX_START_BIT, TX_DATA_BIT, TX_STOP_BIT, CLEANUP } state_t;
  state_t state = IDLE;  // defined power-up state

  // width large enough for CLKS_PER_BIT-1
  localparam int COUNT_W = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;

  logic [COUNT_W-1:0] clock_count = '0;
  logic        [2:0]  bit_index   = '0;
  logic        [7:0]  tx_data     = '0;
  logic               tx_done     = 1'b0;
  logic               tx_act      = 1'b0;

  
  always_ff @(posedge clk) begin
    unique case (state)

      IDLE: begin
        o_tx_ser    <= 1'b1;     // idle high
        tx_done     <= 1'b0;     // clear done pulse
        clock_count <= '0;
        bit_index   <= '0;
        tx_act      <= 1'b0;

        if (tx_dv) begin
          tx_act   <= 1'b1;
          tx_data  <= tx_byte;    // latch data
          state    <= TX_START_BIT;
        end else begin
          state    <= IDLE;
        end
      end

      TX_START_BIT: begin
        o_tx_ser <= 1'b0;         // start bit
        if (clock_count < CLKS_PER_BIT-1) begin
          clock_count <= clock_count + 1'b1;
          state       <= TX_START_BIT;
        end else begin
          clock_count <= '0;
          state       <= TX_DATA_BIT;
        end
      end

      TX_DATA_BIT: begin
        o_tx_ser <= tx_data[bit_index];  // LSB first
        if (clock_count < CLKS_PER_BIT-1) begin
          clock_count <= clock_count + 1'b1;
          state       <= TX_DATA_BIT;
        end else begin
          clock_count <= '0;
          if (bit_index < 3'd7) begin
            bit_index <= bit_index + 3'd1;
            state     <= TX_DATA_BIT;
          end else begin
            bit_index <= '0;
            state     <= TX_STOP_BIT;
          end
        end
      end

      TX_STOP_BIT: begin
        o_tx_ser <= 1'b1;         // stop bit
        if (clock_count < CLKS_PER_BIT-1) begin
          clock_count <= clock_count + 1'b1;
          state       <= TX_STOP_BIT;
        end else begin
          clock_count <= '0;
          tx_done     <= 1'b1;    // 1-cycle done pulse (cleared in IDLE)
          state       <= CLEANUP;
          // tx_act cleared in CLEANUP/IDLE
        end
      end

      CLEANUP: begin
        o_tx_ser <= 1'b1;         // return to idle
        tx_act   <= 1'b0;
        state    <= IDLE;
      end

      default: state <= IDLE;
    endcase
  end

  assign o_tx_act  = tx_act;
  assign o_tx_done = tx_done;

endmodule
