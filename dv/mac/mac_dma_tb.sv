`timescale 1ns/1ps
module mac_dma_tb;
  reg clk=0, rst_n=0, start=0, core_start=0;
  reg [31:0] mem [0:255];
  reg pending=0;
  reg [31:0] pending_data=0;
  wire req, gnt, rvalid, we;
  wire [31:0] addr, wdata, rdata;
  wire [31:0] wd, ad, rd;
  wire wv, av, rv, rlast, wr, ar, rr, core_done;
  wire busy, wdone, adone, rdone;
  integer i, cycles, failures;

  assign gnt = req;
  assign rdata = pending_data;
  always #5 clk=~clk;
  always @(posedge clk) begin
    if (!rst_n) begin
      pending <= 0; pending_data <= 0;
    end else begin
      pending <= req && !we;
      if (req && we)
        mem[addr[9:2]] <= wdata;
      if (req && !we)
        pending_data <= mem[addr[9:2]];
    end
  end

  axi_stream_dma dma (
    .clk(clk), .rst_n(rst_n), .start_i(start), .abort_i(1'b0),
    .wgt_base_i(32'h100), .act_base_i(32'h200), .res_base_i(32'h300),
    .dma_len_wgt_i(32'd64), .dma_len_act_i(32'd16),
    .busy_o(busy), .wgt_done_o(wdone), .act_done_o(adone), .res_done_o(rdone),
    .m_req_o(req), .m_gnt_i(gnt), .m_addr_o(addr), .m_we_o(we), .m_wdata_o(wdata),
    .m_rvalid_i(rvalid), .m_rdata_i(rdata),
    .m_axis_wgt_tdata(wd), .m_axis_wgt_tvalid(wv), .m_axis_wgt_tready(wr),
    .m_axis_act_tdata(ad), .m_axis_act_tvalid(av), .m_axis_act_tready(ar),
    .s_axis_res_tdata(rd), .s_axis_res_tvalid(rv), .s_axis_res_tready(rr),
    .s_axis_res_tlast(rlast));
  assign rvalid = pending;

  mac_core_axi #(.ROWS(4),.COLS(4),.DATA_W(8)) core (
    .clk(clk), .rst_n(rst_n), .s_axis_wgt_tdata(wd), .s_axis_wgt_tvalid(wv), .s_axis_wgt_tready(wr),
    .s_axis_act_tdata(ad), .s_axis_act_tvalid(av), .s_axis_act_tready(ar),
    .m_axis_res_tdata(rd), .m_axis_res_tvalid(rv), .m_axis_res_tready(rr), .m_axis_res_tlast(rlast),
    .core_start_i(core_start), .core_done_o(core_done),
    .reg_m_i(8'd4), .reg_k_i(8'd4), .reg_n_i(8'd4));
  assign rr = 1'b1;

  initial begin
    failures=0; cycles=0;
    for (i=0;i<256;i=i+1) mem[i]=0;
    mem[64]=1; mem[65]=2; mem[66]=3; mem[67]=4;
    mem[68]=2; mem[69]=1; mem[70]=2; mem[71]=1;
    mem[72]=1; mem[73]=3; mem[74]=1; mem[75]=2;
    mem[76]=2; mem[77]=2; mem[78]=1; mem[79]=1;
    mem[128]=1; mem[129]=2; mem[130]=3; mem[131]=4;
    repeat(2) @(posedge clk); rst_n=1;
    @(negedge clk); start=1; @(negedge clk); start=0;
    while (!adone && cycles < 500) begin @(posedge clk); cycles=cycles+1; end
    if (!adone) begin $fatal(1,"MAC_RESULT_PATH FAIL: input DMA timeout"); end
    @(negedge clk); core_start=1; @(negedge clk); core_start=0;
    while (!rdone && cycles < 1500) begin @(posedge clk); cycles=cycles+1; end
    if (!rdone) begin $fatal(1,"MAC_RESULT_PATH FAIL: result DMA timeout"); end
    #1;
    if (mem[192] !== 5 || mem[193] !== 13 || mem[194] !== 14 || mem[195] !== 12) begin
      $display("MAC_RESULT_PATH DEBUG dma_state=%0d core_state=%0d wdone=%b adone=%b rdone=%b core_done=%b wv=%b av=%b rv=%b last=%b",
               dma.state, core.state, wdone, adone, rdone, core_done, wv, av, rv, rlast);
      $display("MAC_RESULT_PATH DEBUG core_result=%08x,%08x,%08x,%08x buffers=%0d,%0d,%0d,%0d",
               core.res_buf[0], core.res_buf[1], core.res_buf[2], core.res_buf[3],
               core.act_buf[0], core.act_buf[1], core.act_buf[2], core.act_buf[3]);
      $fatal(1,"MAC_RESULT_PATH FAIL: writeback=%08x,%08x,%08x,%08x",mem[192],mem[193],mem[194],mem[195]);
    end
    $display("MAC_RESULT_PATH PASS: result stream and DMA writeback [5,13,14,12]");
    $finish;
  end
endmodule
