`timescale 1ns/1ps

module sub_byte(
  input  logic [127:0] in,
  output logic [127:0] out
);
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : g_sbox
      wire [7:0] bin;
      wire [7:0] bout;

      // Take bytes from MSB to LSB: in[127:120] = byte 0, ..., in[7:0] = byte 15
      assign bin = in[127 - 8*i -: 8];

      s_box u0(.x(bin[7:4]), .y(bin[3:0]), .out(bout));

      // Write back in the same MSB-first positions
      assign out[127 - 8*i -: 8] = bout;
    end
  endgenerate
endmodule
