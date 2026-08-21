`timescale 1ns/1ps
module soc_verilator_tb;
  reg clk = 0;
  reg rst_n = 0;
  integer cycles;
  soc_top dut(.clk(clk), .rst_n(rst_n));
  always #5 clk = ~clk;

  initial begin
    cycles = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    while (dut.u_mem.u_ram.mem[80] !== 32'h600d0002 && cycles < 10000) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    if (cycles >= 10000) begin
      $display("VERILATOR_CPU_MAC DEBUG pc=%08x instr_req=%b instr_gnt=%b instr_rvalid=%b pending=%b instr=%08x cpu_req=%b cpu_addr=%08x apb_psel=%b apb_addr=%08x",
               dut.instr_addr, dut.instr_req, dut.instr_gnt, dut.instr_rvalid,
               dut.u_mem.instr_pending, dut.instr_rdata, dut.cpu_req, dut.cpu_addr,
               dut.apb_psel, dut.apb_paddr);
      $display("VERILATOR_CPU_MAC DEBUG mem0=%08x mem1=%08x mem16=%08x mem64=%08x mem80=%08x dma_busy=%b dma_done=%b mac_start=%b mac_done=%b",
               dut.u_mem.u_ram.mem[0], dut.u_mem.u_ram.mem[1], dut.u_mem.u_ram.mem[16],
               dut.u_mem.u_ram.mem[64], dut.u_mem.u_ram.mem[80], dut.dma_busy,
               dut.dma_done, dut.mac_global_start, dut.mac_done);
      $fatal(1, "VERILATOR_CPU_MAC FAIL: timeout");
    end
    if (dut.u_mem.u_ram.mem[64] !== 32'h00000005 ||
        dut.u_mem.u_ram.mem[65] !== 32'h0000000d ||
        dut.u_mem.u_ram.mem[66] !== 32'h0000000e ||
        dut.u_mem.u_ram.mem[67] !== 32'h0000000c)
      $fatal(1, "VERILATOR_CPU_MAC FAIL: result mismatch");
    $display("VERILATOR_CPU_MAC PASS: result [5,13,14,12]");
    $finish;
  end
endmodule
