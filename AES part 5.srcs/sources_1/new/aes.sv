// aes128_core.sv  - plain 'case' version
`timescale 1ns/1ps

module aes128_core (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         start,
  input  logic [127:0] key,
  input  logic [127:0] pt,
  output logic [127:0] ct,
  output logic         done
);
  // -------- key expansion --------
  logic [1407:0] round_keys_flat;
  aes128_key_expand u_kexp(.key_in(key), .round_keys_flat(round_keys_flat));

  // unpack r0..r10 (r0 at MSBs)
  logic [127:0] rk [0:10];
  always_comb begin
    rk[0]  = round_keys_flat[1407 -: 128];
    rk[1]  = round_keys_flat[1279 -: 128];
    rk[2]  = round_keys_flat[1151 -: 128];
    rk[3]  = round_keys_flat[1023 -: 128];
    rk[4]  = round_keys_flat[ 895 -: 128];
    rk[5]  = round_keys_flat[ 767 -: 128];
    rk[6]  = round_keys_flat[ 639 -: 128];
    rk[7]  = round_keys_flat[ 511 -: 128];
    rk[8]  = round_keys_flat[ 383 -: 128];
    rk[9]  = round_keys_flat[ 255 -: 128];
    rk[10] = round_keys_flat[ 127 -: 128];
  end

  // -------- datapath --------
  logic [127:0] state, sb, sr, mc;
  logic [3:0]   round; // 1..10 once started

  sub_byte   u_sb(.in(state), .out(sb));
  shiftrows  u_sr(.in(sb),    .out(sr));
  mixcolumns u_mc(.in(sr),    .out(mc));

  // -------- control FSM --------
  typedef enum logic [1:0] {IDLE, INIT, ROUND, DONE} state_e;
  state_e cs, ns;

  // next-state / outputs (plain case)
  always_comb begin
    ns   = cs;
    done = 1'b0;

    case (cs)
      IDLE : if (start) ns = INIT;           else ns = IDLE;
      INIT : ns = ROUND;
      ROUND: ns = (round == 4'd10) ? DONE : ROUND;
      DONE : begin ns = IDLE; done = 1'b1; end
      default: ns = IDLE;
    endcase
  end

  // registers (plain case)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cs    <= IDLE;
      state <= '0;
      round <= '0;
      ct    <= '0;
    end else begin
      cs <= ns;
      case (cs)
        IDLE: if (start) begin
          // Round 0: AddRoundKey
          state <= pt ^ rk[0];
          round <= 4'd1;
        end

        INIT: begin
          // spacer cycle
          state <= state;
        end

        ROUND: begin
          logic [127:0] next_state;
          if (round < 4'd10) begin
            // rounds 1..9: SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
            next_state = mc ^ rk[round];
            round      <= round + 4'd1;
          end else begin
            // round 10: SubBytes -> ShiftRows -> AddRoundKey
            next_state = sr ^ rk[10];
          end
          state <= next_state;

          if (round == 4'd10) ct <= next_state;
        end

        DONE: /* hold one cycle */ ;

        default: /* do nothing */ ;
      endcase
    end
  end
endmodule
