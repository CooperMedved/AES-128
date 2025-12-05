`timescale 1ns/1ps

module tb_aes128_ecb;
  // clock/reset & IO
  logic         clk;
  logic         rst_n;
  logic         start;
  logic [127:0] key, pt, ct;
  logic         done;

  // 100 MHz clock
  initial clk = 1'b0;
  always  #5 clk = ~clk;

  // synchronous reset
  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  // DUT
  aes128_core dut(
    .clk(clk), .rst_n(rst_n), .start(start),
    .key(key), .pt(pt), .ct(ct), .done(done)
  );

  // -------- Test vectors (FIPS-197) --------
  localparam int N = 3;
  localparam logic [127:0] KEYS [N] = '{
    128'h000102030405060708090A0B0C0D0E0F,
    128'h2B7E151628AED2A6ABF7158809CF4F3C,
    128'h00000000000000000000000000000000
  };
  localparam logic [127:0] PTS  [N] = '{
    128'h01112233445566778899AABBCCDDEEFF,
    128'h6BC1BEE22E409F96E93D7E117393172A,
    128'h00000000000000000000000000000000
  };
  localparam logic [127:0] EXPS [N] = '{
    128'h69C4E0D86A7B0430D8CDB78070B4C55A,
    128'h3AD77BB40D7A3660A89ECAF32466EF97,
    128'h66E94BD4EF8A2C3B884CFA59CA342B2E
  };

  // -------- Round-by-round tracer (first vector only) --------
  initial begin : round_trace
    @(posedge rst_n);

    // Drive vector 0 and give one setup cycle for rk calc
    start = 1'b0; key = '0; pt = '0;
    @(posedge clk);
    key = KEYS[0];
    pt  = PTS[0];
    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    // Round 0 completes when round advances to 1
    wait (dut.round == 4'd1);
    #1;
    $display("R0 (AddRoundKey): state=%032h  rk=%032h", dut.state, dut.rk[0]);

    // Rounds 1..9: print after the state register updates (round just advanced)
    for (int r = 1; r <= 9; r++) begin
      wait (dut.round == r+1);
      #1;
      $display("R%0d: state=%032h  rk=%032h", r, dut.state, dut.rk[r]);
    end

    // Final round: sample on the DONE pulse (one cycle after round-10 calc)
    @(posedge done);
    #1;
    $display("R10 (final): state=%032h  rk=%032h", dut.state, dut.rk[10]);
    $display("CT = %032h  (exp = %032h)", ct, EXPS[0]);

    // small gap before the main loop
    repeat (3) @(posedge clk);
  end

  // -------- Main stimulus for all vectors (including 0 again) --------
  initial begin : main_stim
    bit timed_out;

    start = 1'b0; key = '0; pt = '0;
    @(posedge rst_n);

    for (int i = 0; i < N; i++) begin
      // Drive inputs
      @(posedge clk);
      key = KEYS[i];
      pt  = PTS[i];

      // One setup cycle for key expansion to settle
      @(posedge clk);

      // Pulse start 1 cycle
      start = 1'b1;
      @(posedge clk);
      start = 1'b0;

      // Wait for done (bounded)
      timed_out = 1'b1;
      for (int t = 0; t < 2000; t++) begin
        @(posedge clk);
        if (done) begin
          timed_out = 1'b0;
          break;
        end
      end
      if (timed_out) $fatal(1, "Timeout waiting for done on case %0d", i);

      // Check
      if (ct === EXPS[i]) $display("[PASS %0d] ct=%032h", i, ct);
      else begin
        $display("[FAIL %0d] got=%032h exp=%032h", i, ct, EXPS[i]);
        $fatal(1);
      end

      // idle a couple cycles between cases
      repeat (2) @(posedge clk);
    end

    $display("All tests passed.");
    #20 $finish;
  end
endmodule
