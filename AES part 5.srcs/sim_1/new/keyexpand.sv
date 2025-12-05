// tb_kexp.sv - self-checking TB for aes128_key_expand
`timescale 1ns/1ps

module tb_kexp;
  // DUT I/O
  logic [127:0] key;
  logic [1407:0] rks_flat;

  // DUT
  aes128_key_expand dut(
    .key_in          (key),
    .round_keys_flat (rks_flat)
  );

  // Unpack flat bus into rk[0..10] using variable part-selects
  logic [127:0] rk [0:10];
  always @* begin
    rk[0]  = rks_flat[1407 -: 128];
    rk[1]  = rks_flat[1279 -: 128];
    rk[2]  = rks_flat[1151 -: 128];
    rk[3]  = rks_flat[1023 -: 128];
    rk[4]  = rks_flat[ 895 -: 128];
    rk[5]  = rks_flat[ 767 -: 128];
    rk[6]  = rks_flat[ 639 -: 128];
    rk[7]  = rks_flat[ 511 -: 128];
    rk[8]  = rks_flat[ 383 -: 128];
    rk[9]  = rks_flat[ 255 -: 128];
    rk[10] = rks_flat[ 127 -: 128];
  end

  // Expected round keys (FIPS-197, key = 2b7e151628aed2a6abf7158809cf4f3c)
  localparam logic [127:0] EXP [0:10] = '{
    128'h2B7E151628AED2A6ABF7158809CF4F3C,
    128'hA0FAFE1788542CB123A339392A6C7605,
    128'hF2C295F27A96B9435935807A7359F67F,
    128'h3D80477D4716FE3E1E237E446D7A883B,
    128'hef44a541a8525b7fb671253bdb0bad00,
    128'hd4d1c6f87c839d87caf2b8bc11f915bc,
    128'h6d88a37a110b3efddbf98641ca0093fd,
    128'h4e54f70e5f5fc9f384a64fb24ea6dc4f,
    128'head27321b58dbad2312bf5607f8d292f,
    128'hac7766f319fadc2128d12941575c006e,
    128'hd014f9a8c9ee2589e13f0cc8b6630ca6
  };

  task automatic check_all;
    for (int i = 0; i <= 10; i++) begin
      if (rk[i] !== EXP[i]) begin
        $display("[FAIL] rk[%0d] got=%032h exp=%032h", i, rk[i], EXP[i]);
        $fatal(1);
      end else
        $display("[PASS] rk[%0d] = %032h", i, rk[i]);
    end
  endtask

  initial begin
    key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    #1; // settle comb path
    check_all();
    $display("All round keys match FIPS-197.");
    $finish;
  end
endmodule
