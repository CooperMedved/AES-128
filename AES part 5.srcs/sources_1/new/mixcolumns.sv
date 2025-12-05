// mixcolumns.sv - MSB-first, column-major (byte i = 4*col + row)
// Bytes: in[127:120]=b0, ..., in[7:0]=b15
`timescale 1ns/1ps

module mixcolumns (
  input  logic [127:0] in,
  output logic [127:0] out
);
  // ---------- GF(2^8) helpers (poly x^8 + x^4 + x^3 + x + 1 = 0x11B) ----------
  function automatic logic [7:0] xtime(input logic [7:0] x);
    logic [7:0] x2;
    begin
      x2    = {x[6:0],1'b0};
      xtime = x[7] ? (x2 ^ 8'h1B) : x2;
    end
  endfunction

  function automatic logic [7:0] mul2(input logic [7:0] x);
    mul2 = xtime(x);
  endfunction

  function automatic logic [7:0] mul3(input logic [7:0] x);
    mul3 = xtime(x) ^ x;
  endfunction

  // ---------- Unpack MSB..LSB into byte array ----------
  logic [7:0] s [0:15];
  always_comb {s[0],s[1],s[2],s[3],s[4],s[5],s[6],s[7],
               s[8],s[9],s[10],s[11],s[12],s[13],s[14],s[15]} = in;

  // ---------- MixColumns per column ----------
  logic [7:0] t [0:15];
  integer c;
  logic [7:0] a0,a1,a2,a3;

  always_comb begin
    for (c = 0; c < 4; c = c + 1) begin
      a0 = s[4*c + 0];
      a1 = s[4*c + 1];
      a2 = s[4*c + 2];
      a3 = s[4*c + 3];

      // b = M * a, where
      // M = [02 03 01 01; 01 02 03 01; 01 01 02 03; 03 01 01 02]
      t[4*c + 0] = mul2(a0) ^ mul3(a1) ^        a2  ^        a3;
      t[4*c + 1] =        a0  ^ mul2(a1) ^ mul3(a2) ^        a3;
      t[4*c + 2] =        a0  ^        a1  ^ mul2(a2) ^ mul3(a3);
      t[4*c + 3] = mul3(a0) ^        a1  ^        a2  ^ mul2(a3);
    end
  end

  // ---------- Pack back MSB..LSB ----------
  assign out = {t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],
                t[8],t[9],t[10],t[11],t[12],t[13],t[14],t[15]};
endmodule
