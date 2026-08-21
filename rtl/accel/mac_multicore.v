/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off PINCONNECTEMPTY */
/* verilator lint_off UNUSEDPARAM */
module mac_multicore #(
    parameter ROWS   = 32,
    parameter COLS   = 32,
    parameter DATA_W = 8,
    parameter NUM_CORES = 4
) (
    input  wire        clk,
    input  wire        rst_n,

    // APB Config Interface
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,

    // AXI4-Stream Data Interfaces for Core 0
    input  wire [31:0] s_axis_wgt_tdata_0,
    input  wire        s_axis_wgt_tvalid_0,
    output wire        s_axis_wgt_tready_0,
    input  wire [31:0] s_axis_act_tdata_0,
    input  wire        s_axis_act_tvalid_0,
    output wire        s_axis_act_tready_0,
    output wire [31:0] m_axis_res_tdata_0,
    output wire        m_axis_res_tvalid_0,
    input  wire        m_axis_res_tready_0,
    output wire        m_axis_res_tlast_0,

    // AXI4-Stream Data Interfaces for Core 1
    input  wire [31:0] s_axis_wgt_tdata_1,
    input  wire        s_axis_wgt_tvalid_1,
    output wire        s_axis_wgt_tready_1,
    input  wire [31:0] s_axis_act_tdata_1,
    input  wire        s_axis_act_tvalid_1,
    output wire        s_axis_act_tready_1,
    output wire [31:0] m_axis_res_tdata_1,
    output wire        m_axis_res_tvalid_1,
    input  wire        m_axis_res_tready_1,
    output wire        m_axis_res_tlast_1,

    // AXI4-Stream Data Interfaces for Core 2
    input  wire [31:0] s_axis_wgt_tdata_2,
    input  wire        s_axis_wgt_tvalid_2,
    output wire        s_axis_wgt_tready_2,
    input  wire [31:0] s_axis_act_tdata_2,
    input  wire        s_axis_act_tvalid_2,
    output wire        s_axis_act_tready_2,
    output wire [31:0] m_axis_res_tdata_2,
    output wire        m_axis_res_tvalid_2,
    input  wire        m_axis_res_tready_2,
    output wire        m_axis_res_tlast_2,

    // AXI4-Stream Data Interfaces for Core 3
    input  wire [31:0] s_axis_wgt_tdata_3,
    input  wire        s_axis_wgt_tvalid_3,
    output wire        s_axis_wgt_tready_3,
    input  wire [31:0] s_axis_act_tdata_3,
    input  wire        s_axis_act_tvalid_3,
    output wire        s_axis_act_tready_3,
    output wire [31:0] m_axis_res_tdata_3,
    output wire        m_axis_res_tvalid_3,
    input  wire        m_axis_res_tready_3,
    output wire        m_axis_res_tlast_3,

    output wire        done_o,
    output wire [3:0]  core_active_o,
    input  wire        dma_busy_i,
    input  wire        dma_done_i,
    input  wire        dma_inputs_done_i,
    input  wire        dma_wgt_done_i,
    input  wire        dma_act_done_i,
    input  wire        dma_res_done_i,
    output wire [31:0] wgt_base_o,
    output wire [31:0] act_base_o,
    output wire [31:0] res_base_o,
    output wire [31:0] dma_len_wgt_o,
    output wire [31:0] dma_len_act_o,
    output wire [3:0]  core_en_o
);

    wire        global_start;
    wire [1:0]  mode;
    wire [3:0]  core_en;
    wire [3:0]  core_done;
    wire [31:0] base_wgt_addr;
    wire [31:0] base_act_addr;
    wire [31:0] base_res_addr;
    wire [31:0] dma_len_wgt_cfg;
    wire [31:0] dma_len_act_cfg;
    wire [7:0]  dim_m, dim_k, dim_n;

    mac_cfg_regs u_regs (
        .clk(clk), .rst_n(rst_n),
        .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata),
        .prdata(prdata), .pready(pready),
        .start_o(global_start),
        .abort_o(),
        .dim_m_o(dim_m), .dim_k_o(dim_k), .dim_n_o(dim_n),
        .core_en_o(core_en),
        .wgt_base_o(base_wgt_addr),
        .act_base_o(base_act_addr),
        .res_base_o(base_res_addr),
        .dma_len_wgt_o(dma_len_wgt_cfg),
        .dma_len_act_o(dma_len_act_cfg),
        .busy_i(|core_active_o | dma_busy_i),
        .done_i(done_o & dma_done_i),
        .wgt_done_i(dma_wgt_done_i),
        .act_done_i(dma_act_done_i),
        .res_done_i(dma_res_done_i)
    );

    assign wgt_base_o = base_wgt_addr;
    assign act_base_o = base_act_addr;
    assign res_base_o = base_res_addr;
    assign dma_len_wgt_o = dma_len_wgt_cfg;
    assign dma_len_act_o = dma_len_act_cfg;
    assign core_en_o = core_en;

    reg [3:0] core_done_r;
    reg       core_launched_r;
    reg       operation_active_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            begin
                core_done_r <= 4'b0000;
                core_launched_r <= 1'b0;
                operation_active_r <= 1'b0;
            end
        else begin
            core_done_r <= core_done;
            if (global_start) begin
                core_done_r <= 4'b0000;
                core_launched_r <= 1'b0;
                operation_active_r <= 1'b1;
            end else if (dma_inputs_done_i && !core_launched_r)
                core_launched_r <= 1'b1;
            if (operation_active_r && &(~core_en | core_done_r) && dma_done_i)
                operation_active_r <= 1'b0;
        end
    end

    assign done_o = operation_active_r && &(~core_en | core_done_r);
    assign core_active_o = operation_active_r ? (core_en & ~core_done_r) : 4'b0;

    wire core_launch = dma_inputs_done_i && !core_launched_r && !global_start;
    wire core_start_0 = core_launch && core_en[0] && ~core_done_r[0];

    // Stagger core starts by 1 cycle each to prevent bus contention phase-lock
    reg core_start_1_d, core_start_2_d, core_start_3_d;
    reg core_start_2_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            core_start_1_d  <= 1'b0;
            core_start_2_d  <= 1'b0;
            core_start_2_d2 <= 1'b0;
            core_start_3_d  <= 1'b0;
        end else begin
            core_start_1_d  <= core_launch && core_en[1] && ~core_done_r[1];
            core_start_2_d  <= core_launch && core_en[2] && ~core_done_r[2];
            core_start_2_d2 <= core_start_2_d;
            core_start_3_d  <= core_launch && core_en[3] && ~core_done_r[3];
        end
    end

    wire core_start_1 = core_start_1_d;
    wire core_start_2 = core_start_2_d2;
    wire core_start_3 = core_start_3_d;

    mac_core_axi #(.ROWS(ROWS), .COLS(COLS), .DATA_W(DATA_W)) u_core_0 (
        .clk(clk), .rst_n(rst_n),
        .s_axis_wgt_tdata(s_axis_wgt_tdata_0),
        .s_axis_wgt_tvalid(s_axis_wgt_tvalid_0),
        .s_axis_wgt_tready(s_axis_wgt_tready_0),
        .s_axis_act_tdata(s_axis_act_tdata_0),
        .s_axis_act_tvalid(s_axis_act_tvalid_0),
        .s_axis_act_tready(s_axis_act_tready_0),
        .m_axis_res_tdata(m_axis_res_tdata_0),
        .m_axis_res_tvalid(m_axis_res_tvalid_0),
        .m_axis_res_tready(m_axis_res_tready_0),
        .m_axis_res_tlast(m_axis_res_tlast_0),
        .core_start_i(core_start_0), .core_done_o(core_done[0]),
        .reg_m_i(dim_m), .reg_k_i(dim_k), .reg_n_i(dim_n)
    );

    mac_core_axi #(.ROWS(ROWS), .COLS(COLS), .DATA_W(DATA_W)) u_core_1 (
        .clk(clk), .rst_n(rst_n),
        .s_axis_wgt_tdata(s_axis_wgt_tdata_1),
        .s_axis_wgt_tvalid(s_axis_wgt_tvalid_1),
        .s_axis_wgt_tready(s_axis_wgt_tready_1),
        .s_axis_act_tdata(s_axis_act_tdata_1),
        .s_axis_act_tvalid(s_axis_act_tvalid_1),
        .s_axis_act_tready(s_axis_act_tready_1),
        .m_axis_res_tdata(m_axis_res_tdata_1),
        .m_axis_res_tvalid(m_axis_res_tvalid_1),
        .m_axis_res_tready(m_axis_res_tready_1),
        .m_axis_res_tlast(m_axis_res_tlast_1),
        .core_start_i(core_start_1), .core_done_o(core_done[1]),
        .reg_m_i(dim_m), .reg_k_i(dim_k), .reg_n_i(dim_n)
    );

    mac_core_axi #(.ROWS(ROWS), .COLS(COLS), .DATA_W(DATA_W)) u_core_2 (
        .clk(clk), .rst_n(rst_n),
        .s_axis_wgt_tdata(s_axis_wgt_tdata_2),
        .s_axis_wgt_tvalid(s_axis_wgt_tvalid_2),
        .s_axis_wgt_tready(s_axis_wgt_tready_2),
        .s_axis_act_tdata(s_axis_act_tdata_2),
        .s_axis_act_tvalid(s_axis_act_tvalid_2),
        .s_axis_act_tready(s_axis_act_tready_2),
        .m_axis_res_tdata(m_axis_res_tdata_2),
        .m_axis_res_tvalid(m_axis_res_tvalid_2),
        .m_axis_res_tready(m_axis_res_tready_2),
        .m_axis_res_tlast(m_axis_res_tlast_2),
        .core_start_i(core_start_2), .core_done_o(core_done[2]),
        .reg_m_i(dim_m), .reg_k_i(dim_k), .reg_n_i(dim_n)
    );

    mac_core_axi #(.ROWS(ROWS), .COLS(COLS), .DATA_W(DATA_W)) u_core_3 (
        .clk(clk), .rst_n(rst_n),
        .s_axis_wgt_tdata(s_axis_wgt_tdata_3),
        .s_axis_wgt_tvalid(s_axis_wgt_tvalid_3),
        .s_axis_wgt_tready(s_axis_wgt_tready_3),
        .s_axis_act_tdata(s_axis_act_tdata_3),
        .s_axis_act_tvalid(s_axis_act_tvalid_3),
        .s_axis_act_tready(s_axis_act_tready_3),
        .m_axis_res_tdata(m_axis_res_tdata_3),
        .m_axis_res_tvalid(m_axis_res_tvalid_3),
        .m_axis_res_tready(m_axis_res_tready_3),
        .m_axis_res_tlast(m_axis_res_tlast_3),
        .core_start_i(core_start_3), .core_done_o(core_done[3]),
        .reg_m_i(dim_m), .reg_k_i(dim_k), .reg_n_i(dim_n)
    );

endmodule
