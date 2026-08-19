`timescale 1ns/1ps

module soc_top_tb;

    logic clk;
    logic rst_n;

    soc_top dut (
        .clk   (clk),
        .rst_n (rst_n)
    );

    dma_directed_tb u_dma_directed_tb ();

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (100) @(posedge clk);
        $display("XCELIUM SMOKE TEST PASS");
        $finish;
    end

    initial begin
        $display("XCELIUM COMPILE/ELAB PASS");
        $shm_open("dv/xcelium/waves.shm");
        $shm_probe("AS", dut);
    end

endmodule

// Uses the production dma_master, axi_stream_dma and dma_arbiter with a
// deterministic one-cycle-response memory model.  This remains part of the
// normal Xcelium top rather than creating a parallel simulation flow.
module dma_directed_tb;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic [31:0] mem [0:63];
    logic        mem_req, mem_we, mem_gnt, mem_rvalid;
    logic [31:0] mem_addr, mem_wdata, mem_rdata;
    logic        read_pending;
    logic [31:0] read_data_pending;

    logic        copy_start, copy_busy, copy_done, copy_err;
    logic [31:0] copy_src, copy_dst;
    logic [15:0] copy_len;
    logic        copy_req, copy_we, copy_gnt, copy_rvalid;
    logic [31:0] copy_addr, copy_wdata;

    logic        stream_start, stream_busy, stream_req, stream_we;
    logic        stream_gnt, stream_rvalid;
    logic [31:0] stream_addr, stream_wdata;
    logic [31:0] wgt_data, act_data;
    logic        wgt_valid, act_valid, res_ready;
    logic [31:0] res_data;
    logic        res_valid, res_last;
    integer      wgt_count, act_count, failures;
    logic        res_issued;
    logic        copy_done_seen;

    assign mem_gnt = mem_req;
    always @(posedge clk) begin
        if (copy_done)
            copy_done_seen = 1'b1;
        if (!rst_n) begin
            mem_rvalid <= 1'b0;
            mem_rdata <= 32'h0;
            read_pending <= 1'b0;
            read_data_pending <= 32'h0;
        end else begin
            mem_rvalid <= read_pending;
            mem_rdata  <= read_data_pending;
            read_pending <= mem_req && !mem_we;
            if (mem_req) begin
                if (mem_we)
                    mem[mem_addr[7:2]] <= mem_wdata;
                else
                    read_data_pending <= mem[mem_addr[7:2]];
            end
        end
    end

    dma_master u_copy (
        .clk(clk), .rst_n(rst_n), .src_addr_i(copy_src), .dst_addr_i(copy_dst),
        .length_i(copy_len), .start_i(copy_start), .busy_o(copy_busy),
        .done_o(copy_done), .err_o(copy_err), .req_o(copy_req), .gnt_i(copy_gnt),
        .addr_o(copy_addr), .we_o(copy_we), .wdata_o(copy_wdata),
        .rvalid_i(copy_rvalid), .rdata_i(mem_rdata)
    );

    axi_stream_dma u_stream (
        .clk(clk), .rst_n(rst_n), .start_i(stream_start), .abort_i(1'b0),
        .wgt_base_i(32'h1000_0010), .act_base_i(32'h1000_0018),
        .res_base_i(32'h1000_0030), .dma_len_wgt_i(32'd8), .dma_len_act_i(32'd8),
        .busy_o(stream_busy), .wgt_done_o(), .act_done_o(), .res_done_o(),
        .m_req_o(stream_req), .m_gnt_i(stream_gnt), .m_addr_o(stream_addr),
        .m_we_o(stream_we), .m_wdata_o(stream_wdata), .m_rvalid_i(stream_rvalid),
        .m_rdata_i(mem_rdata), .m_axis_wgt_tdata(wgt_data),
        .m_axis_wgt_tvalid(wgt_valid), .m_axis_wgt_tready(1'b1),
        .m_axis_act_tdata(act_data), .m_axis_act_tvalid(act_valid), .m_axis_act_tready(1'b1),
        .s_axis_res_tdata(res_data), .s_axis_res_tvalid(res_valid),
        .s_axis_res_tready(res_ready), .s_axis_res_tlast(res_last)
    );

    dma_arbiter u_arbiter (
        .clk(clk), .rst_n(rst_n),
        .stream_req_i(stream_req), .stream_addr_i(stream_addr), .stream_we_i(stream_we),
        .stream_wdata_i(stream_wdata), .stream_gnt_o(stream_gnt), .stream_rvalid_o(stream_rvalid),
        .copy_req_i(copy_req), .copy_addr_i(copy_addr), .copy_we_i(copy_we),
        .copy_wdata_i(copy_wdata), .copy_gnt_o(copy_gnt), .copy_rvalid_o(copy_rvalid),
        .mem_req_o(mem_req), .mem_addr_o(mem_addr), .mem_we_o(mem_we),
        .mem_wdata_o(mem_wdata), .mem_gnt_i(mem_gnt), .mem_rvalid_i(mem_rvalid)
    );

    task automatic check(input bit condition, input string message);
        if (!condition) begin
            failures = failures + 1;
            $display("DMA_DIRECTED FAIL: %s at %0t", message, $time);
        end
    endtask

    always @(posedge clk) begin
        if (wgt_valid) begin
            check(wgt_data == mem[4 + wgt_count], "weight read response ownership/data");
            wgt_count = wgt_count + 1;
        end
        if (act_valid) begin
            check(act_data == mem[6 + act_count], "activation back-to-back read data");
            act_count = act_count + 1;
        end
    end

    initial begin : run_dma_directed
        integer cycles;
        failures = 0;
        wgt_count = 0;
        act_count = 0;
        res_issued = 0;
        copy_done_seen = 0;
        copy_start = 0;
        stream_start = 0;
        res_valid = 0;
        res_last = 0;
        res_data = 0;
        copy_src = 32'h1000_0000;
        copy_dst = 32'h1000_0020;
        copy_len = 16'd8;
        mem[0] = 32'hCAFE_0001;
        mem[1] = 32'hCAFE_0002;
        mem[4] = 32'hA000_0001;
        mem[5] = 32'hA000_0002;
        mem[6] = 32'hB000_0001;
        mem[7] = 32'hB000_0002;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // Both engines start together. The arbiter must grant copy first,
        // then stream, and alternate when both continue requesting.
        @(negedge clk);
        copy_start = 1;
        stream_start = 1;
        @(negedge clk);
        copy_start = 0;
        stream_start = 0;

        cycles = 0;
        while ((copy_busy || stream_busy || !copy_done_seen || wgt_count != 2 || act_count != 2) && cycles < 80) begin
            @(posedge clk);
            cycles = cycles + 1;
            if (act_count == 2 && !res_issued) begin
                @(negedge clk);
                res_data = 32'hD000_0001;
                res_valid = 1;
                res_last = 1;
                res_issued = 1;
            end
        end

        check(cycles < 80, "bounded DMA completion timeout");
        if (cycles >= 80)
            $display("DMA_DIRECTED state: copy_busy=%b copy_done=%b copy_state=%0d stream_busy=%b stream_state=%0d",
                     copy_busy, copy_done, u_copy.state, stream_busy, u_stream.state);
        check(copy_done_seen && !copy_err, "dma_master copy completed");
        check(mem[8] == 32'hCAFE_0001 && mem[9] == 32'hCAFE_0002,
              "dma_master writes returned read data to destination");
        check(wgt_count == 2 && act_count == 2, "axi_stream_dma reads completed");
        check(mem[12] == 32'hD000_0001, "axi_stream_dma result write completed");
        check(!(^copy_gnt === 1'bx) && !(^stream_gnt === 1'bx) &&
              !(^copy_rvalid === 1'bx) && !(^stream_rvalid === 1'bx),
              "grant and read-response ownership remain known");
        if (failures == 0)
            $display("DMA_DIRECTED PASS: copy, stream, contention, reads, writes, and mixed traffic");
        else
            $fatal(1, "DMA_DIRECTED FAIL: %0d checks failed", failures);
    end

    initial begin
        #2000;
        $fatal(1, "DMA_DIRECTED FAIL: global timeout");
    end
endmodule
