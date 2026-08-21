`timescale 1ns/1ps
module sram_banked_tb;
  reg clk = 0, cen = 1, wen = 1;
  reg [11:0] addr = 0;
  reg [3:0] mask = 4'hf;
  reg [31:0] din = 0;
  wire [31:0] dout;
  integer failures = 0;

  sram_wrapper_banked_4096x32 dut (
    .clk(clk), .sram_cen(cen), .sram_wen(wen), .sram_addr(addr),
    .sram_wmask(mask), .sram_din(din), .sram_dout(dout));
  always #5 clk = ~clk;

  task automatic write_word(input [11:0] a, input [31:0] d);
    begin
      @(negedge clk); addr=a; din=d; cen=0; wen=0;
      @(posedge clk); #1;
      @(negedge clk); cen=1; wen=1;
    end
  endtask

  task automatic read_check(input [11:0] a, input [31:0] expected);
    begin
      @(negedge clk); addr=a; cen=0; wen=1;
      @(posedge clk); #1;
      if (dout !== expected) begin
        $display("SRAM_BANKED_TEST FAIL: addr=%0d got=%08x expected=%08x", a, dout, expected);
        failures = failures + 1;
      end
      @(negedge clk); cen=1;
    end
  endtask

  initial begin
    write_word(12'd0,    32'h0000_00aa);
    write_word(12'd255,  32'h2552_5500);
    write_word(12'd256,  32'h2562_5600);
    write_word(12'd511,  32'h5115_1100);
    write_word(12'd4095, 32'hffff_4095);
    read_check(12'd0,    32'h0000_00aa);
    read_check(12'd255,  32'h2552_5500);
    read_check(12'd256,  32'h2562_5600);
    read_check(12'd511,  32'h5115_1100);
    read_check(12'd4095, 32'hffff_4095);
    if (failures == 0) begin
      $display("SRAM_BANKED_TEST PASS: addresses 0,255,256,511,4095 and bank boundaries");
      $finish;
    end
    $fatal(1, "SRAM_BANKED_TEST FAIL: %0d checks failed", failures);
  end
endmodule
