module soc_top (
    input  wire        clk,
    input  wire        rst_n
);

    wire [31:0] instr_addr      /* verilator public_flat_rd */;
    wire        dma_busy        /* verilator public_flat_rd */;
    wire        mac_done        /* verilator public_flat_rd */;
    wire [3:0]  mac_core_active /* verilator public_flat_rd */;
    wire        mac_global_start /* verilator public_flat_rd */;
    wire [3:0]  mac_gnt_vec    /* verilator public_flat_rd */;

    wire instr_req, instr_gnt, instr_rvalid;
    wire [31:0] instr_rdata;
    wire cpu_req, cpu_gnt, cpu_rvalid, cpu_we;
    wire [3:0]  cpu_be;
    wire [31:0] cpu_addr, cpu_wdata, cpu_rdata;

    // The memory subsystem exposes one DMA request port.  The programmed-copy
    // DMA and the MAC streaming DMA are independent masters of that port.
    wire        dma_m_req, dma_m_gnt, dma_m_rvalid, dma_m_we;
    wire [31:0] dma_m_addr, dma_m_wdata, dma_m_rdata;
    wire        stream_dma_req, stream_dma_gnt, stream_dma_rvalid, stream_dma_we;
    wire [31:0] stream_dma_addr, stream_dma_wdata;
    wire        copy_dma_req, copy_dma_gnt, copy_dma_rvalid, copy_dma_we;
    wire [31:0] copy_dma_addr, copy_dma_wdata;

    wire [31:0] apb_paddr, apb_pwdata, apb_bus_data, cpu_rdata_apb;
    wire        apb_psel, apb_penable, apb_pwrite, apb_pready, cpu_gnt_apb, cpu_rvalid_apb;
    wire [5:0]  s_psel;
    wire [31:0] s0_prdata, s1_prdata;

    wire [31:0] cpu_rdata_mem;
    wire        cpu_rvalid_mem;

    reg [1:0] rst_sync;
    wire rst_n_int;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rst_sync <= 2'b0;
        else rst_sync <= {rst_sync[0], 1'b1};
    end
    assign rst_n_int = rst_sync[1];

    // Qualify the address decode with a valid request.  Ibex requires its
    // grant input to be known even while its request address is don't-care.
    wire cpu_is_periph = cpu_req && (cpu_addr[31:20] == 12'h400);
    wire cpu_is_mem    = cpu_req && !cpu_is_periph;
    reg  cpu_response_from_periph;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cpu_response_from_periph <= 1'b0;
        else if (cpu_req && cpu_gnt)
            cpu_response_from_periph <= cpu_is_periph;
    end

    dma_arbiter u_dma_arbiter (
        .clk(clk), .rst_n(rst_n_int),
        .stream_req_i(stream_dma_req), .stream_addr_i(stream_dma_addr),
        .stream_we_i(stream_dma_we), .stream_wdata_i(stream_dma_wdata),
        .stream_gnt_o(stream_dma_gnt), .stream_rvalid_o(stream_dma_rvalid),
        .copy_req_i(copy_dma_req), .copy_addr_i(copy_dma_addr),
        .copy_we_i(copy_dma_we), .copy_wdata_i(copy_dma_wdata),
        .copy_gnt_o(copy_dma_gnt), .copy_rvalid_o(copy_dma_rvalid),
        .mem_req_o(dma_m_req), .mem_addr_o(dma_m_addr), .mem_we_o(dma_m_we),
        .mem_wdata_o(dma_m_wdata), .mem_gnt_i(dma_m_gnt),
        .mem_rvalid_i(dma_m_rvalid)
    );

    ibex_top #(.RV32M(ibex_pkg::RV32MFast), .RV32B(ibex_pkg::RV32BNone), .SecureIbex(1'b0)) u_core (
        .clk_i(clk), .rst_ni(rst_n_int), .test_en_i(1'b0), .hart_id_i(32'h0), .boot_addr_i(32'h0),
        .instr_req_o(instr_req), .instr_gnt_i(instr_gnt), .instr_addr_o(instr_addr),
        .instr_rdata_i(instr_rdata), .instr_rvalid_i(instr_rvalid),
        .instr_err_i(1'b0), .instr_rdata_intg_i(7'h0),
        .data_req_o(cpu_req), .data_gnt_i(cpu_gnt), .data_we_o(cpu_we), .data_be_o(cpu_be),
        .data_addr_o(cpu_addr), .data_wdata_o(cpu_wdata), .data_rdata_i(cpu_rdata), .data_rvalid_i(cpu_rvalid),
        .data_err_i(1'b0), .data_rdata_intg_i(7'h0), .data_wdata_intg_o(),
        .fetch_enable_i(4'h1), .debug_req_i(1'b0), .scan_rst_ni(1'b1), .irq_nm_i(1'b0),
        .irq_software_i(1'b0), .irq_timer_i(1'b0), .irq_external_i(1'b0), .irq_fast_i(15'h0),
        .scramble_key_valid_i(1'b0), .scramble_key_i(128'h0), .scramble_nonce_i(64'h0), .scramble_req_o(),
        .ram_cfg_icache_tag_i(12'h000), .ram_cfg_icache_data_i(12'h000), .ram_cfg_rsp_icache_tag_o(), .ram_cfg_rsp_icache_data_o(),
        .alert_minor_o(), .alert_major_internal_o(), .alert_major_bus_o(), .core_sleep_o(),
        .crash_dump_o(), .double_fault_seen_o(), .lockstep_cmp_en_o(), .data_req_shadow_o(),
        .data_we_shadow_o(), .data_be_shadow_o(), .data_addr_shadow_o(), .data_wdata_shadow_o(),
        .data_wdata_intg_shadow_o(), .instr_req_shadow_o(), .instr_addr_shadow_o()
    );

    // -----------------------------------------------------------------
    // Dedicated Local SRAM buffers feeding the 32x32 array boundary
    // -----------------------------------------------------------------
    wire [31:0] sram_wgt_dout, sram_act_dout, sram_res_dout;
    wire        sram_wgt_cen = !(dma_m_req && dma_m_addr[31:28] == 4'hE); // Weight SRAM mapping
    wire        sram_act_cen = !(dma_m_req && dma_m_addr[31:28] == 4'hD); // Activation SRAM mapping
    wire        sram_res_cen = !(dma_m_req && dma_m_addr[31:28] == 4'hC); // Result SRAM mapping

    sram_wrapper #(.DEPTH(4096), .ADDR_WIDTH(12)) u_buf_wgt (
        .clk(clk),
        .sram_cen(sram_wgt_cen),
        .sram_wen(!dma_m_we),
        .sram_addr(dma_m_addr[13:2]),
        .sram_wmask(4'hF),
        .sram_din(dma_m_wdata),
        .sram_dout(sram_wgt_dout)
    );

    sram_wrapper #(.DEPTH(4096), .ADDR_WIDTH(12)) u_buf_act (
        .clk(clk),
        .sram_cen(sram_act_cen),
        .sram_wen(!dma_m_we),
        .sram_addr(dma_m_addr[13:2]),
        .sram_wmask(4'hF),
        .sram_din(dma_m_wdata),
        .sram_dout(sram_act_dout)
    );

    sram_wrapper #(.DEPTH(4096), .ADDR_WIDTH(12)) u_buf_res (
        .clk(clk),
        .sram_cen(sram_res_cen),
        .sram_wen(!dma_m_we),
        .sram_addr(dma_m_addr[13:2]),
        .sram_wmask(4'hF),
        .sram_din(dma_m_wdata),
        .sram_dout(sram_res_dout)
    );

    // Stream feed mapping via AXI-S DMA Engine
    wire [31:0] axis_wgt_tdata;
    wire        axis_wgt_tvalid;
    wire        axis_wgt_tready;
    wire [31:0] axis_act_tdata;
    wire        axis_act_tvalid;
    wire        axis_act_tready;
    wire [31:0] axis_res_tdata;
    wire        axis_res_tvalid;
    wire        axis_res_tready;
    wire        axis_res_tlast;
    wire        mac_dma_busy, mac_dma_wgt_done, mac_dma_act_done, mac_dma_res_done;
    wire [31:0] mac_wgt_base, mac_act_base, mac_res_base;
    wire [31:0] mac_dma_len_wgt, mac_dma_len_act;

    axi_stream_dma u_mac_dma (
        .clk(clk),
        .rst_n(rst_n_int),
        .start_i(mac_global_start),
        .abort_i(1'b0),
        .wgt_base_i(mac_wgt_base),
        .act_base_i(mac_act_base),
        .res_base_i(mac_res_base),
        .dma_len_wgt_i(mac_dma_len_wgt),
        .dma_len_act_i(mac_dma_len_act),
        .busy_o(mac_dma_busy),
        .wgt_done_o(mac_dma_wgt_done),
        .act_done_o(mac_dma_act_done),
        .res_done_o(mac_dma_res_done),
        .m_req_o(stream_dma_req),
        .m_gnt_i(stream_dma_gnt),
        .m_addr_o(stream_dma_addr),
        .m_we_o(stream_dma_we),
        .m_wdata_o(stream_dma_wdata),
        .m_rvalid_i(stream_dma_rvalid),
        .m_rdata_i(dma_m_rdata),
        .m_axis_wgt_tdata(axis_wgt_tdata),
        .m_axis_wgt_tvalid(axis_wgt_tvalid),
        .m_axis_wgt_tready(axis_wgt_tready),
        .m_axis_act_tdata(axis_act_tdata),
        .m_axis_act_tvalid(axis_act_tvalid),
        .m_axis_act_tready(axis_act_tready),
        .s_axis_res_tdata(axis_res_tdata),
        .s_axis_res_tvalid(axis_res_tvalid),
        .s_axis_res_tready(axis_res_tready),
        .s_axis_res_tlast(axis_res_tlast)
    );

    // mem_subsystem arbitrates four MAC request slots internally. Keep all four
    // ports present when the accelerator is disconnected, and tie them inactive.
    mem_subsystem #(.NUM_MAC_MASTERS(4)) u_mem (
        .clk(clk), .rst_n(rst_n_int),
        .instr_req(instr_req), .instr_addr(instr_addr), .instr_rdata(instr_rdata),
        .instr_rvalid(instr_rvalid), .instr_gnt(instr_gnt),
        .cpu_req(cpu_is_mem), .cpu_addr(cpu_addr), .cpu_we(cpu_we),
        .cpu_be(cpu_be), .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata_mem), .cpu_rvalid(cpu_rvalid_mem),
        .dma_req(dma_m_req && dma_m_addr[31:28] < 4'hC), .dma_addr(dma_m_addr), .dma_we(dma_m_we),
        .dma_wdata(dma_m_wdata), .dma_rdata(dma_m_rdata),
        .dma_gnt(dma_m_gnt), .dma_rvalid(dma_m_rvalid),
        .mac_req(4'b0), .mac_addr('{32'h0, 32'h0, 32'h0, 32'h0}), .mac_we(4'b0),
        .mac_wdata('{32'h0, 32'h0, 32'h0, 32'h0}), .mac_rdata(),
        .mac_gnt(), .mac_rvalid()
    );

    obi_to_apb u_bridge (
        .clk(clk), .rst_n(rst_n_int),
        .obi_req(cpu_is_periph), .obi_gnt(cpu_gnt_apb), .obi_addr(cpu_addr),
        .obi_we(cpu_we), .obi_wdata(cpu_wdata),
        .obi_rvalid(cpu_rvalid_apb), .obi_rdata(cpu_rdata_apb),
        .paddr(apb_paddr), .psel(apb_psel), .penable(apb_penable),
        .pwrite(apb_pwrite), .pwdata(apb_pwdata), .pready(apb_pready), .prdata(apb_bus_data)
    );

    apb_bus u_bus (
        .m_paddr(apb_paddr), .m_psel(apb_psel), .m_penable(apb_penable),
        .m_pwrite(apb_pwrite), .m_pwdata(apb_pwdata),
        .m_prdata(apb_bus_data), .m_pready(apb_pready),
        .s_psel(s_psel),
        .s0_prdata(s0_prdata), .s0_pready(1'b1),
        .s1_prdata(s1_prdata), .s1_pready(1'b1),
        .s2_prdata(32'h0), .s2_pready(1'b1),
        .s3_prdata(32'h0), .s3_pready(1'b1),
        .s4_prdata(32'h0), .s4_pready(1'b1),
        .s5_prdata(32'h0), .s5_pready(1'b1)
    );

    wire dma_done, dma_err, dma_abort;
    wire [31:0] d_src, d_dst;
    wire [15:0] d_len;
    wire        d_start;

    dma_regs u_dma_regs (
        .clk(clk), .rst_n(rst_n_int),
        .psel(s_psel[0]), .penable(apb_penable), .paddr(apb_paddr),
        .pwrite(apb_pwrite), .pwdata(apb_pwdata), .prdata(s0_prdata), .pready(),
        .src_addr_o(d_src), .dst_addr_o(d_dst), .length_o(d_len),
        .start_o(d_start), .abort_o(dma_abort),
        .busy_i(dma_busy), .done_i(dma_done), .err_i(dma_err),
        .irq_ack_o()
    );

    dma_master u_dma_core (
        .clk(clk), .rst_n(rst_n_int),
        .src_addr_i(d_src), .dst_addr_i(d_dst), .length_i(d_len),
        .start_i(d_start), .busy_o(dma_busy), .done_o(dma_done), .err_o(dma_err),
        .req_o(copy_dma_req), .gnt_i(copy_dma_gnt), .addr_o(copy_dma_addr), .we_o(copy_dma_we),
        .wdata_o(copy_dma_wdata), .rvalid_i(copy_dma_rvalid), .rdata_i(dma_m_rdata)
    );

    mac_multicore #(
        .ROWS(32), .COLS(32), .DATA_W(8), .NUM_CORES(4)
    ) u_mac (
        .clk(clk), .rst_n(rst_n_int),
        .paddr(apb_paddr), .psel(s_psel[1]), .penable(apb_penable),
        .pwrite(apb_pwrite), .pwdata(apb_pwdata), .prdata(s1_prdata), .pready(),
        
        .s_axis_wgt_tdata_0(axis_wgt_tdata), .s_axis_wgt_tvalid_0(axis_wgt_tvalid), .s_axis_wgt_tready_0(axis_wgt_tready),
        .s_axis_act_tdata_0(axis_act_tdata), .s_axis_act_tvalid_0(axis_act_tvalid), .s_axis_act_tready_0(axis_act_tready),
        .m_axis_res_tdata_0(axis_res_tdata), .m_axis_res_tvalid_0(axis_res_tvalid), .m_axis_res_tready_0(axis_res_tready), .m_axis_res_tlast_0(axis_res_tlast),

        .s_axis_wgt_tdata_1(axis_wgt_tdata), .s_axis_wgt_tvalid_1(axis_wgt_tvalid), .s_axis_wgt_tready_1(),
        .s_axis_act_tdata_1(axis_act_tdata), .s_axis_act_tvalid_1(axis_act_tvalid), .s_axis_act_tready_1(),
        .m_axis_res_tdata_1(), .m_axis_res_tvalid_1(), .m_axis_res_tready_1(1'b1), .m_axis_res_tlast_1(),

        .s_axis_wgt_tdata_2(axis_wgt_tdata), .s_axis_wgt_tvalid_2(axis_wgt_tvalid), .s_axis_wgt_tready_2(),
        .s_axis_act_tdata_2(axis_act_tdata), .s_axis_act_tvalid_2(axis_act_tvalid), .s_axis_act_tready_2(),
        .m_axis_res_tdata_2(), .m_axis_res_tvalid_2(), .m_axis_res_tready_2(1'b1), .m_axis_res_tlast_2(),

        .s_axis_wgt_tdata_3(axis_wgt_tdata), .s_axis_wgt_tvalid_3(axis_wgt_tvalid), .s_axis_wgt_tready_3(),
        .s_axis_act_tdata_3(axis_act_tdata), .s_axis_act_tvalid_3(axis_act_tvalid), .s_axis_act_tready_3(),
        .m_axis_res_tdata_3(), .m_axis_res_tvalid_3(), .m_axis_res_tready_3(1'b1), .m_axis_res_tlast_3(),

        .done_o(mac_done),
        .core_active_o(mac_core_active),
        .dma_busy_i(mac_dma_busy),
        .dma_done_i(mac_dma_res_done),
        .dma_inputs_done_i(mac_dma_wgt_done & mac_dma_act_done),
        .dma_wgt_done_i(mac_dma_wgt_done), .dma_act_done_i(mac_dma_act_done),
        .dma_res_done_i(mac_dma_res_done),
        .wgt_base_o(mac_wgt_base), .act_base_o(mac_act_base),
        .res_base_o(mac_res_base), .dma_len_wgt_o(mac_dma_len_wgt),
        .dma_len_act_o(mac_dma_len_act), .core_en_o()
    );

    wire dma_stall = dma_m_req && !dma_m_gnt;
    wire pe_active  = |mac_core_active;
    wire acc_ovfl   = 1'b0;

    telemetry u_telemetry (
        .clk(clk), .rst_n(rst_n_int),
        .pe_valid_i(mac_done), .dma_stall_i(dma_stall),
        .acc_ovfl_i(acc_ovfl), .pe_active_i(pe_active),
        .paddr(apb_paddr), .psel(s_psel[2]), .penable(apb_penable),
        .pwrite(apb_pwrite), .pwdata(apb_pwdata),
        .prdata(), .pready()
    );

    assign cpu_gnt    = cpu_req ? (cpu_is_periph ? cpu_gnt_apb : 1'b1) : 1'b0;
    assign cpu_rvalid = cpu_response_from_periph ? cpu_rvalid_apb : cpu_rvalid_mem;
    assign cpu_rdata  = cpu_response_from_periph ? cpu_rdata_apb  : cpu_rdata_mem;

    assign mac_global_start = u_mac.global_start;
    assign mac_gnt_vec      = 4'b0;

endmodule
