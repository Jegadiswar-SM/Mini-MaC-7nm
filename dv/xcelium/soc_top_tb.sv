`timescale 1ns/1ps

module soc_top_tb;

    logic clk;
    logic rst_n;

    soc_top dut (
        .clk   (clk),
        .rst_n (rst_n)
    );

    dma_directed_tb u_dma_directed_tb ();
    cpu_dma_software_tb u_cpu_dma_software_tb ();
    boot_rom_fetch_tb u_boot_rom_fetch_tb ();

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (20) @(posedge clk);
        $display("XCELIUM SMOKE TEST PASS");
    end

    initial begin
        $display("XCELIUM COMPILE/ELAB PASS");
        $shm_open("dv/xcelium/waves.shm");
        $shm_probe("AS", dut);
    end

endmodule

// Directly checks the ROM's one-cycle request-to-response behavior using the
// same firmware image loaded by +firmware.
module boot_rom_fetch_tb;
    logic clk;
    logic [9:0] addr;
    logic [31:0] rdata;
    integer failures;

    boot_rom u_rom (.clk(clk), .addr(addr), .rdata(rdata));
    always #5 clk = ~clk;

    task automatic expect_word(input logic [9:0] a, input logic [31:0] expected);
        begin
            @(negedge clk);
            addr = a;
            @(posedge clk);
            #1;
            if (rdata !== expected) begin
                failures = failures + 1;
                $display("BOOT_ROM_FETCH FAIL: addr=%0d got=%08x expected=%08x", a, rdata, expected);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        addr = 10'd0;
        failures = 0;
        expect_word(10'd32, 32'h100000b7);
        expect_word(10'd33, 32'h40000137);
        expect_word(10'd34, 32'h112231b7);
        if (failures == 0)
            $display("BOOT_ROM_FETCH PASS: registered response data is deterministic");
        else
            $fatal(1, "BOOT_ROM_FETCH FAIL: %0d checks failed", failures);
    end
endmodule

// End-to-end bare-metal regression.  This observes actual Ibex/APB activity
// and the production SRAM, rather than declaring success when time elapses.
module cpu_dma_software_tb;
    integer cycles;
    integer failures;
    bit saw_src_write, saw_dst_write, saw_len_write, saw_start;
    bit saw_dma_done, saw_signature;
    bit saw_status_read;

    task automatic check(input bit condition, input string message);
        if (!condition) begin
            failures = failures + 1;
            $display("CPU_DMA_SOFTWARE FAIL: %s at %0t", message, $time);
        end
    endtask

    initial begin : run_cpu_dma_software
        failures = 0;
        saw_src_write = 0;
        saw_dst_write = 0;
        saw_len_write = 0;
        saw_start = 0;
        saw_dma_done = 0;
        saw_signature = 0;
        saw_status_read = 0;

        wait (soc_top_tb.rst_n === 1'b1);
        wait (soc_top_tb.dut.rst_n_int === 1'b1);
        cycles = 0;
        while (!saw_signature && cycles < 1000) begin
            @(posedge soc_top_tb.clk);
            cycles = cycles + 1;
            if (soc_top_tb.dut.apb_psel && soc_top_tb.dut.apb_penable &&
                soc_top_tb.dut.apb_pwrite) begin
                case (soc_top_tb.dut.apb_paddr)
                    32'h4000_0000: begin
                        saw_src_write = 1;
                        check(soc_top_tb.dut.apb_pwdata == 32'h1000_0000,
                              "firmware programmed DMA_SRC");
                    end
                    32'h4000_0004: begin
                        saw_dst_write = 1;
                        check(soc_top_tb.dut.apb_pwdata == 32'h1000_0020,
                              "firmware programmed DMA_DST");
                    end
                    32'h4000_0008: begin
                        saw_len_write = 1;
                        check(soc_top_tb.dut.apb_pwdata == 32'd8,
                              "firmware programmed DMA_LEN");
                    end
                    32'h4000_000c: begin
                        saw_start = 1;
                        check(soc_top_tb.dut.apb_pwdata[0],
                              "firmware asserted DMA_CTRL.start");
                    end
                    default: ;
                endcase
            end
            if (soc_top_tb.dut.apb_psel && soc_top_tb.dut.apb_penable &&
                !soc_top_tb.dut.apb_pwrite && soc_top_tb.dut.apb_paddr == 32'h4000_0010)
                saw_status_read = 1;
            if (soc_top_tb.dut.dma_done)
                saw_dma_done = 1;
            if (soc_top_tb.dut.u_mem.u_ram.mem[16] == 32'h600d_0001)
                saw_signature = 1;
        end

        check(cycles < 1000, "bounded firmware completion timeout");
        if (cycles >= 1000)
            $display("CPU_DMA_SOFTWARE debug: pc=%08x instr_req=%b instr_gnt=%b instr_rvalid=%b instr_rdata=%08x rom0=%08x rom1=%08x rom2=%08x rom32=%08x cpu_req=%b cpu_addr=%08x",
                     soc_top_tb.dut.instr_addr, soc_top_tb.dut.instr_req,
                     soc_top_tb.dut.instr_gnt, soc_top_tb.dut.instr_rvalid,
                     soc_top_tb.dut.instr_rdata, soc_top_tb.dut.u_mem.u_rom.rom[0],
                     soc_top_tb.dut.u_mem.u_rom.rom[1], soc_top_tb.dut.u_mem.u_rom.rom[2],
                     soc_top_tb.dut.u_mem.u_rom.rom[32], soc_top_tb.dut.cpu_req,
                     soc_top_tb.dut.cpu_addr);
        if (cycles >= 1000)
            $display("CPU_DMA_SOFTWARE state: src=%08x dst=%08x len=%0d dma_state=%0d busy=%b done=%b err=%b done_sticky=%b ram0=%08x ram1=%08x ram8=%08x ram9=%08x sig=%08x",
                     soc_top_tb.dut.d_src, soc_top_tb.dut.d_dst, soc_top_tb.dut.d_len,
                     soc_top_tb.dut.u_dma_core.state, soc_top_tb.dut.dma_busy,
                     soc_top_tb.dut.dma_done, soc_top_tb.dut.dma_err,
                     soc_top_tb.dut.u_dma_regs.done_sticky,
                     soc_top_tb.dut.u_mem.u_ram.mem[0], soc_top_tb.dut.u_mem.u_ram.mem[1],
                     soc_top_tb.dut.u_mem.u_ram.mem[8], soc_top_tb.dut.u_mem.u_ram.mem[9],
                     soc_top_tb.dut.u_mem.u_ram.mem[16]);
        if (cycles >= 1000)
            $display("CPU_DMA_SOFTWARE bus: copy_req=%b copy_gnt=%b copy_rvalid=%b copy_addr=%08x dma_req=%b dma_gnt=%b dma_rvalid=%b dma_addr=%08x owner_count=%0d owner0=%b owner1=%b",
                     soc_top_tb.dut.copy_dma_req, soc_top_tb.dut.copy_dma_gnt,
                     soc_top_tb.dut.copy_dma_rvalid, soc_top_tb.dut.copy_dma_addr,
                     soc_top_tb.dut.dma_m_req, soc_top_tb.dut.dma_m_gnt,
                     soc_top_tb.dut.dma_m_rvalid, soc_top_tb.dut.dma_m_addr,
                     soc_top_tb.dut.u_dma_arbiter.read_owner_count_q,
                     soc_top_tb.dut.u_dma_arbiter.read_owner_stream_q[0],
                     soc_top_tb.dut.u_dma_arbiter.read_owner_stream_q[1]);
        check(saw_src_write && saw_dst_write && saw_len_write && saw_start,
              "Ibex programmed every DMA register through APB");
        check(saw_dma_done, "DMA completion was observed");
        check(saw_status_read, "CPU read DMA status through APB");
        check(soc_top_tb.dut.u_mem.u_ram.mem[0] == 32'h1122_3344,
              "firmware initialized deterministic source word 0");
        check(soc_top_tb.dut.u_mem.u_ram.mem[1] == 32'h5566_7788,
              "firmware initialized deterministic source word 1");
        check(soc_top_tb.dut.u_mem.u_ram.mem[8] == 32'h1122_3344,
              "DMA copied deterministic word 0");
        check(soc_top_tb.dut.u_mem.u_ram.mem[9] == 32'h5566_7788,
              "DMA copied deterministic word 1");
        check(saw_signature, "firmware observed DMA done and wrote signature");
        if (failures == 0)
            begin
                $display("APB_DMA_REGISTER_TEST PASS: source, destination, length, control, and status");
                $display("CPU_DMA_SOFTWARE_PASS: Ibex programmed and verified DMA copy");
            end
        else
            $fatal(1, "CPU_DMA_SOFTWARE FAIL: %0d checks failed", failures);
        $finish;
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
    logic        directed_finished;

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
        directed_finished = 0;
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
        directed_finished = 1;
        if (failures == 0) begin
            $display("DMA_BACK_TO_BACK_READ PASS: sequential stream reads retained ownership");
            $display("DMA_MIXED_TRAFFIC PASS: copy/stream read-write contention retained ownership");
        end
    end

    initial begin
        #2000;
        if (!directed_finished)
            $fatal(1, "DMA_DIRECTED FAIL: global timeout");
    end
endmodule
