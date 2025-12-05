// shiftrows.sv - MSB-first, column-major mapping (byte i = 4*col + row)
// Bytes: in[127:120]=b0, ..., in[7:0]=b15
`timescale 1ns/1ps

module shiftrows(
  input  logic [127:0] in,
  output logic [127:0] out
);
  logic [7:0] s [0:15], t [0:15];

  // unpack MSB..LSB
  always_comb {s[0],s[1],s[2],s[3],s[4],s[5],s[6],s[7],
               s[8],s[9],s[10],s[11],s[12],s[13],s[14],s[15]} = in;

  // Row 0: no shift
  assign t[0]  = s[0];
  assign t[4]  = s[4];
  assign t[8]  = s[8];
  assign t[12] = s[12];

  // Row 1: shift left by 1
  assign t[1]  = s[5];
  assign t[5]  = s[9];
  assign t[9]  = s[13];
  assign t[13] = s[1];

  // Row 2: shift left by 2
  assign t[2]  = s[10];
  assign t[6]  = s[14];
  assign t[10] = s[2];
  assign t[14] = s[6];

  // Row 3: shift left by 3
  assign t[3]  = s[15];
  assign t[7]  = s[3];
  assign t[11] = s[7];
  assign t[15] = s[11];

  // pack MSB..LSB
  assign out = {t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],
                t[8],t[9],t[10],t[11],t[12],t[13],t[14],t[15]};
endmodule
