// Code your design here

// AES-128 key schedule: emits 11 round keys (r0..r10) packed high→low.

`timescale 1ns/1ps

// ---------------------------
// SubWord: apply S-box to 32b
// ---------------------------
module subword(
  input  logic [31:0] in_w,
  output logic [31:0] out_w
);
  logic [7:0] b3, b2, b1, b0;
  logic [7:0] sb3, sb2, sb1, sb0;

  assign {b3,b2,b1,b0} = in_w;

  // Use the external s_box module (from s-box.sv)
  s_box s3(.x(b3[7:4]), .y(b3[3:0]), .out(sb3));
  s_box s2(.x(b2[7:4]), .y(b2[3:0]), .out(sb2));
  s_box s1(.x(b1[7:4]), .y(b1[3:0]), .out(sb1));
  s_box s0(.x(b0[7:4]), .y(b0[3:0]), .out(sb0));

  assign out_w = {sb3, sb2, sb1, sb0};
endmodule

// ---------------------------------------------------------
// One key-expansion step: computes w[i] from w[i-1], w[i-4]
// DO_G = 1 for i%4==0 (use g() and RCON), else pass-through
// ---------------------------------------------------------
module kexp_word #(
  parameter bit           DO_G  = 1'b1,
  parameter logic [31:0]  RCON  = 32'h0
)(
  input  logic [31:0] win_m4,   // w[i-4]
  input  logic [31:0] win_m1,   // w[i-1]
  output logic [31:0] wout      // w[i]
);
  logic [31:0] rot, sub, temp_g, temp;

  // RotWord and SubWord
  assign rot   = {win_m1[23:0], win_m1[31:24]}; // rotate left by one byte
  subword u_sub(.in_w(rot), .out_w(sub));

  // g() and pass-through select
  assign temp_g = sub ^ RCON;                   // g() = SubWord(RotWord) ^ Rcon
  assign temp   = DO_G ? temp_g : win_m1;

  // Next word
  assign wout = win_m4 ^ temp;
endmodule

// ---------------------------------------------------------
// AES-128 Key Expansion: emits all 44 words (w0..w43)
// round_keys_flat packs r0..r10 consecutively (high..low):
//   {r0, r1, r2, ..., r10}, each rX is 128 bits.
// ---------------------------------------------------------
module aes128_key_expand (
  input  logic [127:0]  key_in,
  output logic [1407:0] round_keys_flat
);
  // Rcon (MSB byte only), rounds 1..10
  localparam logic [31:0] R1  = 32'h01_00_00_00, R2  = 32'h02_00_00_00;
  localparam logic [31:0] R3  = 32'h04_00_00_00, R4  = 32'h08_00_00_00;
  localparam logic [31:0] R5  = 32'h10_00_00_00, R6  = 32'h20_00_00_00;
  localparam logic [31:0] R7  = 32'h40_00_00_00, R8  = 32'h80_00_00_00;
  localparam logic [31:0] R9  = 32'h1B_00_00_00, R10 = 32'h36_00_00_00;

  logic [31:0] w0, w1, w2, w3,
               w4, w5, w6, w7,
               w8, w9, w10, w11,
               w12, w13, w14, w15,
               w16, w17, w18, w19,
               w20, w21, w22, w23,
               w24, w25, w26, w27,
               w28, w29, w30, w31,
               w32, w33, w34, w35,
               w36, w37, w38, w39,
               w40, w41, w42, w43;

  // Map input key to words (big-endian word order)
  assign {w0, w1, w2, w3} = key_in;

  // w4..w7
  kexp_word #(.DO_G(1), .RCON(R1 )) u_w4 (.win_m4(w0), .win_m1(w3), .wout(w4));
  kexp_word #(.DO_G(0))             u_w5 (.win_m4(w1), .win_m1(w4), .wout(w5));
  kexp_word #(.DO_G(0))             u_w6 (.win_m4(w2), .win_m1(w5), .wout(w6));
  kexp_word #(.DO_G(0))             u_w7 (.win_m4(w3), .win_m1(w6), .wout(w7));

  // w8..w11
  kexp_word #(.DO_G(1), .RCON(R2 )) u_w8  (.win_m4(w4),  .win_m1(w7),  .wout(w8 ));
  kexp_word #(.DO_G(0))             u_w9  (.win_m4(w5),  .win_m1(w8 ), .wout(w9 ));
  kexp_word #(.DO_G(0))             u_w10 (.win_m4(w6),  .win_m1(w9 ), .wout(w10));
  kexp_word #(.DO_G(0))             u_w11 (.win_m4(w7),  .win_m1(w10), .wout(w11));

  // w12..w15
  kexp_word #(.DO_G(1), .RCON(R3 )) u_w12 (.win_m4(w8 ), .win_m1(w11), .wout(w12));
  kexp_word #(.DO_G(0))             u_w13 (.win_m4(w9 ), .win_m1(w12), .wout(w13));
  kexp_word #(.DO_G(0))             u_w14 (.win_m4(w10), .win_m1(w13), .wout(w14));
  kexp_word #(.DO_G(0))             u_w15 (.win_m4(w11), .win_m1(w14), .wout(w15));

  // w16..w19
  kexp_word #(.DO_G(1), .RCON(R4 )) u_w16 (.win_m4(w12), .win_m1(w15), .wout(w16));
  kexp_word #(.DO_G(0))             u_w17 (.win_m4(w13), .win_m1(w16), .wout(w17));
  kexp_word #(.DO_G(0))             u_w18 (.win_m4(w14), .win_m1(w17), .wout(w18));
  kexp_word #(.DO_G(0))             u_w19 (.win_m4(w15), .win_m1(w18), .wout(w19));

  // w20..w23
  kexp_word #(.DO_G(1), .RCON(R5 )) u_w20 (.win_m4(w16), .win_m1(w19), .wout(w20));
  kexp_word #(.DO_G(0))             u_w21 (.win_m4(w17), .win_m1(w20), .wout(w21));
  kexp_word #(.DO_G(0))             u_w22 (.win_m4(w18), .win_m1(w21), .wout(w22));
  kexp_word #(.DO_G(0))             u_w23 (.win_m4(w19), .win_m1(w22), .wout(w23));

  // w24..w27
  kexp_word #(.DO_G(1), .RCON(R6 )) u_w24 (.win_m4(w20), .win_m1(w23), .wout(w24));
  kexp_word #(.DO_G(0))             u_w25 (.win_m4(w21), .win_m1(w24), .wout(w25));
  kexp_word #(.DO_G(0))             u_w26 (.win_m4(w22), .win_m1(w25), .wout(w26));
  kexp_word #(.DO_G(0))             u_w27 (.win_m4(w23), .win_m1(w26), .wout(w27));

  // w28..w31
  kexp_word #(.DO_G(1), .RCON(R7 )) u_w28 (.win_m4(w24), .win_m1(w27), .wout(w28));
  kexp_word #(.DO_G(0))             u_w29 (.win_m4(w25), .win_m1(w28), .wout(w29));
  kexp_word #(.DO_G(0))             u_w30 (.win_m4(w26), .win_m1(w29), .wout(w30));
  kexp_word #(.DO_G(0))             u_w31 (.win_m4(w27), .win_m1(w30), .wout(w31));

  // w32..w35
  kexp_word #(.DO_G(1), .RCON(R8 )) u_w32 (.win_m4(w28), .win_m1(w31), .wout(w32));
  kexp_word #(.DO_G(0))             u_w33 (.win_m4(w29), .win_m1(w32), .wout(w33));
  kexp_word #(.DO_G(0))             u_w34 (.win_m4(w30), .win_m1(w33), .wout(w34));
  kexp_word #(.DO_G(0))             u_w35 (.win_m4(w31), .win_m1(w34), .wout(w35));

  // w36..w39
  kexp_word #(.DO_G(1), .RCON(R9 )) u_w36 (.win_m4(w32), .win_m1(w35), .wout(w36));
  kexp_word #(.DO_G(0))             u_w37 (.win_m4(w33), .win_m1(w36), .wout(w37));
  kexp_word #(.DO_G(0))             u_w38 (.win_m4(w34), .win_m1(w37), .wout(w38));
  kexp_word #(.DO_G(0))             u_w39 (.win_m4(w35), .win_m1(w38), .wout(w39));

  // w40..w43
  kexp_word #(.DO_G(1), .RCON(R10)) u_w40 (.win_m4(w36), .win_m1(w39), .wout(w40));
  kexp_word #(.DO_G(0))             u_w41 (.win_m4(w37), .win_m1(w40), .wout(w41));
  kexp_word #(.DO_G(0))             u_w42 (.win_m4(w38), .win_m1(w41), .wout(w42));
  kexp_word #(.DO_G(0))             u_w43 (.win_m4(w39), .win_m1(w42), .wout(w43));

  // Pack r0..r10 = 11*128b (high to low)
  assign round_keys_flat = {
    w0,  w1,  w2,  w3,   // r0
    w4,  w5,  w6,  w7,   // r1
    w8,  w9,  w10, w11,  // r2
    w12, w13, w14, w15,  // r3
    w16, w17, w18, w19,  // r4
    w20, w21, w22, w23,  // r5
    w24, w25, w26, w27,  // r6
    w28, w29, w30, w31,  // r7
    w32, w33, w34, w35,  // r8
    w36, w37, w38, w39,  // r9
    w40, w41, w42, w43   // r10
  };
endmodule
