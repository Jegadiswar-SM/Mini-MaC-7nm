`timescale 1ns/1ps
module mac_tb;
  reg clk = 0, rst_n = 0, start = 0, wvalid = 0, avalid = 0;
  reg [31:0] wdata = 0, adata = 0;
  wire wready, aready, rvalid, rlast, done;
  wire [31:0] rdata;
  integer i, count, failures;
  reg [31:0] observed [0:3];
  reg [7:0] weights [0:15];
  reg [7:0] activations [0:3];

  mac_core_axi #(.ROWS(4), .COLS(4), .DATA_W(8)) dut (
    .clk(clk), .rst_n(rst_n),
    .s_axis_wgt_tdata(wdata), .s_axis_wgt_tvalid(wvalid), .s_axis_wgt_tready(wready),
    .s_axis_act_tdata(adata), .s_axis_act_tvalid(avalid), .s_axis_act_tready(aready),
    .m_axis_res_tdata(rdata), .m_axis_res_tvalid(rvalid), .m_axis_res_tready(1'b1),
    .m_axis_res_tlast(rlast), .core_start_i(start), .core_done_o(done),
    .reg_m_i(8'd4), .reg_k_i(8'd4), .reg_n_i(8'd4));

  always #5 clk = ~clk;

  task automatic send_vector;
    begin
      for (i = 0; i < 16; i = i + 1) begin
        @(negedge clk); wdata = {24'h0, weights[i]}; wvalid = 1'b1;
        @(negedge clk); wvalid = 1'b0;
      end
      for (i = 0; i < 4; i = i + 1) begin
        @(negedge clk); adata = {24'h0, activations[i]}; avalid = 1'b1;
        @(negedge clk); avalid = 1'b0;
      end
      @(negedge clk); start = 1'b1;
      @(negedge clk); start = 1'b0;
      count = 0;
      while (!done && count < 200) begin
        @(posedge clk);
        if (rvalid) begin
          observed[count] = rdata;
          count = count + 1;
        end
      end
      if (count != 4) begin
        $display("MAC_FUNCTIONAL_TEST FAIL: result count=%0d", count);
        failures = failures + 1;
      end
      $display("MAC_VECTOR result=%08x,%08x,%08x,%08x last=%b done=%b",
               observed[0], observed[1], observed[2], observed[3], rlast, done);
    end
  endtask

  task automatic check_result(input [31:0] e0, input [31:0] e1,
                              input [31:0] e2, input [31:0] e3);
    begin
      if (observed[0] !== e0 || observed[1] !== e1 ||
          observed[2] !== e2 || observed[3] !== e3) begin
        $display("MAC_FUNCTIONAL_TEST FAIL: got %08x,%08x,%08x,%08x expected %08x,%08x,%08x,%08x",
                 observed[0], observed[1], observed[2], observed[3], e0, e1, e2, e3);
        failures = failures + 1;
      end
    end
  endtask

  task automatic reset_core;
    begin
      @(negedge clk); rst_n = 1'b0;
      repeat (2) @(posedge clk);
      @(negedge clk); rst_n = 1'b1;
    end
  endtask

  initial begin
    failures = 0;
    weights[0]=1; weights[1]=2; weights[2]=3; weights[3]=4;
    weights[4]=2; weights[5]=1; weights[6]=2; weights[7]=1;
    weights[8]=1; weights[9]=3; weights[10]=1; weights[11]=2;
    weights[12]=2; weights[13]=2; weights[14]=1; weights[15]=1;
    activations[0]=1; activations[1]=2; activations[2]=3; activations[3]=4;
    repeat (2) @(posedge clk); rst_n = 1'b1;
    send_vector();
    check_result(32'd5, 32'd13, 32'd14, 32'd12);

    reset_core();
    activations[0]=4; activations[1]=3; activations[2]=2; activations[3]=1;
    send_vector();
    check_result(32'd10, 32'd17, 32'd21, 32'd8);

    reset_core();
    activations[0]=1; activations[1]=2; activations[2]=3; activations[3]=4;
    for (i = 0; i < 16; i = i + 1) weights[i] = weights[i] * 2;
    send_vector();
    check_result(32'd10, 32'd26, 32'd28, 32'd24);
    if (failures == 0)
      $display("MAC_FUNCTIONAL_TEST PASS: activation and weight sensitivity verified");
    else
      $fatal(1, "MAC_FUNCTIONAL_TEST FAIL: %0d checks failed", failures);
    $finish;
  end
endmodule
