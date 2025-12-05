`timescale 1ns / 1ps


module uart_rx #(
  parameter int unsigned CLKS_PER_BIT = 868
)(
  input  logic       clk,
  input  logic       rx_serial,
  output logic       o_rx_dv,
  output logic [7:0] o_rx_byte
);

  typedef enum logic [2:0] {
    IDLE, RX_START_BIT, RX_DATA_BIT, RX_STOP_BIT, CLEANUP
  } state_t;

  // width large enough for CLKS_PER_BIT-1
  localparam int COUNT_W = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;

  logic rx_data_r = 1'b1;
  logic rx_data   = 1'b1;

  logic [COUNT_W-1:0] clock_count = '0;  
  logic [2:0]         bit_index   = 0;
  logic [7:0]         rx_byte     = 0;
  logic               rx_dv       = 0;

  state_t state = IDLE;                  

  always_ff @(posedge clk) begin
    rx_data_r <= rx_serial;
    rx_data   <= rx_data_r;
  end

  always_ff @(posedge clk) begin
    case (state)
      IDLE: begin
        rx_dv       <= 1'b0;
        clock_count <= '0;
        bit_index   <= 0;
        if (rx_data == 1'b0) state <= RX_START_BIT;
        else                 state <= IDLE;
      end
      RX_START_BIT: begin
        if (clock_count == (CLKS_PER_BIT-1)/2) begin
          if (rx_data == 1'b0) begin
            clock_count <= '0;
            state       <= RX_DATA_BIT;
          end else begin
            state <= IDLE;
          end
        end else begin
          clock_count <= clock_count + 1;
          state       <= RX_START_BIT;
        end
      end
      RX_DATA_BIT: begin
        if (clock_count < CLKS_PER_BIT-1) begin
          clock_count <= clock_count + 1;
          state       <= RX_DATA_BIT;
        end else begin
          clock_count            <= '0;
          rx_byte[bit_index]     <= rx_data;
          if (bit_index < 7) begin
            bit_index <= bit_index + 1;
            state     <= RX_DATA_BIT;
          end else begin
            bit_index <= 0;
            state     <= RX_STOP_BIT;
          end
        end
      end
      RX_STOP_BIT: begin
        if (clock_count < CLKS_PER_BIT-1) begin
          clock_count <= clock_count + 1;
          state       <= RX_STOP_BIT;
        end else begin
          rx_dv       <= 1'b1;
          clock_count <= '0;
          state       <= CLEANUP;
        end
      end
      CLEANUP: begin
        state <= IDLE;
        rx_dv <= 1'b0;
      end
      default: state <= IDLE;
    endcase
  end

  assign o_rx_dv   = rx_dv;
  assign o_rx_byte = rx_byte;

endmodule
