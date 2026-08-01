/* verilator lint_off UNUSEDSIGNAL */
// =============================================================================
// mac_core_axi.v — Upgraded Single MAC Core with Local SRAM & AXI-S Ports
// =============================================================================
module mac_core_axi #(
    parameter ROWS   = 32,
    parameter COLS   = 32,
    parameter DATA_W = 8,
    parameter WGT_DEPTH = 4096,
    parameter ACT_DEPTH = 2048,
    parameter RES_DEPTH = 4096
) (
    input  wire        clk,
    input  wire        rst_n,

    // AXI4-Stream Weight Input
    input  wire [31:0] s_axis_wgt_tdata,
    input  wire        s_axis_wgt_tvalid,
    output wire        s_axis_wgt_tready,

    // AXI4-Stream Activation Input
    input  wire [31:0] s_axis_act_tdata,
    input  wire        s_axis_act_tvalid,
    output wire        s_axis_act_tready,

    // AXI4-Stream Result Output
    output reg  [31:0] m_axis_res_tdata,
    output reg         m_axis_res_tvalid,
    input  wire        m_axis_res_tready,
    output reg         m_axis_res_tlast,

    // Controls
    input  wire        core_start_i,
    output reg         core_done_o,

    // Configuration
    input  wire [7:0]  reg_m_i,
    input  wire [7:0]  reg_k_i,
    input  wire [7:0]  reg_n_i
);

    assign s_axis_wgt_tready = 1'b1;
    assign s_axis_act_tready = 1'b1;

    // Local SRAM Weight Buffer
    reg  [11:0] wgt_waddr;
    wire [31:0] wgt_dout;
    sram_wrapper #(.DEPTH(WGT_DEPTH), .ADDR_WIDTH(12)) u_buf_wgt (
        .clk(clk),
        .sram_cen(!(s_axis_wgt_tvalid)),
        .sram_wen(1'b0), // active LOW write
        .sram_addr(wgt_waddr),
        .sram_wmask(4'hF),
        .sram_din(s_axis_wgt_tdata),
        .sram_dout(wgt_dout)
    );

    // Local SRAM Activation Buffer
    reg  [11:0] act_waddr;
    wire [31:0] act_dout;
    sram_wrapper #(.DEPTH(ACT_DEPTH), .ADDR_WIDTH(12)) u_buf_act (
        .clk(clk),
        .sram_cen(!(s_axis_act_tvalid)),
        .sram_wen(1'b0),
        .sram_addr(act_waddr),
        .sram_wmask(4'hF),
        .sram_din(s_axis_act_tdata),
        .sram_dout(act_dout)
    );

    // Local SRAM Result Buffer
    reg  [11:0] res_addr;
    reg         res_wen;
    reg  [31:0] res_din;
    wire [31:0] res_dout;
    sram_wrapper #(.DEPTH(RES_DEPTH), .ADDR_WIDTH(12)) u_buf_res (
        .clk(clk),
        .sram_cen(1'b0),
        .sram_wen(res_wen),
        .sram_addr(res_addr),
        .sram_wmask(4'hF),
        .sram_din(res_din),
        .sram_dout(res_dout)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wgt_waddr <= 0;
            act_waddr <= 0;
        end else begin
            if (s_axis_wgt_tvalid) wgt_waddr <= wgt_waddr + 1;
            if (s_axis_act_tvalid) act_waddr <= act_waddr + 1;
        end
    end

    // Simple arrays and systolic mapping
    reg [DATA_W-1:0] wgt_buf [0:ROWS-1][0:COLS-1];
    reg [DATA_W-1:0] act_buf [0:ROWS-1];
    reg [31:0]       res_buf [0:COLS-1];

    wire [DATA_W-1:0] w_in_wires [0:ROWS-1][0:COLS-1];
    wire [31:0]        col_in_wires [0:COLS-1];
    wire [31:0]        col_out_wires [0:COLS-1];
    reg                load_wgt_r;
    reg [DATA_W-1:0]   row_in_r [0:ROWS-1];

    genvar gi, gj;
    generate
        for (gi = 0; gi < ROWS; gi = gi + 1) begin : gen_wgt_r
            for (gj = 0; gj < COLS; gj = gj + 1) begin : gen_wgt_c
                assign w_in_wires[gi][gj] = wgt_buf[gi][gj];
            end
        end
    endgenerate

    genvar gk;
    generate
        for (gk = 0; gk < COLS; gk = gk + 1) begin : gen_col_in
            assign col_in_wires[gk] = 32'd0;
        end
    endgenerate

    systolic_array #(
        .ROWS(ROWS), .COLS(COLS), .DATA_W(DATA_W)
    ) u_array (
        .clk      (clk),
        .rst_n    (rst_n),
        .load_wgt (load_wgt_r),
        .row_in   (row_in_r),
        .w_in     (w_in_wires),
        .col_in   (col_in_wires),
        .col_out  (col_out_wires)
    );

    localparam [2:0]
        ST_IDLE      = 3'd0,
        ST_LOAD_WGT  = 3'd1,
        ST_FEED      = 3'd2,
        ST_DRAIN     = 3'd3,
        ST_WRITE_RES = 3'd4,
        ST_STREAM_OUT= 3'd5;

    reg [2:0] state;
    reg [7:0] r_cnt;
    reg [7:0] c_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            core_done_o <= 1'b0;
            load_wgt_r  <= 1'b0;
            res_wen     <= 1'b1;
            m_axis_res_tvalid <= 1'b0;
            m_axis_res_tlast  <= 1'b0;
        end else begin
            load_wgt_r <= 1'b0;
            res_wen    <= 1'b1; // active LOW wen, so 1'b1 = disable write

            case (state)
                ST_IDLE: begin
                    core_done_o <= 1'b0;
                    if (core_start_i) begin
                        state <= ST_LOAD_WGT;
                    end
                end

                ST_LOAD_WGT: begin
                    load_wgt_r <= 1'b1;
                    state      <= ST_FEED;
                    r_cnt      <= 0;
                end

                ST_FEED: begin
                    // simple feed-through mapping
                    r_cnt <= r_cnt + 1;
                    if (r_cnt == reg_m_i - 1) begin
                        state <= ST_DRAIN;
                        c_cnt <= 0;
                    end
                end

                ST_DRAIN: begin
                    c_cnt <= c_cnt + 1;
                    if (c_cnt == reg_n_i - 1) begin
                        state <= ST_WRITE_RES;
                        r_cnt <= 0;
                    end
                end

                ST_WRITE_RES: begin
                    res_wen <= 1'b0; // write to RES sram
                    res_addr <= r_cnt;
                    res_din <= col_out_wires[r_cnt];
                    r_cnt <= r_cnt + 1;
                    if (r_cnt == reg_n_i - 1) begin
                        state <= ST_STREAM_OUT;
                        r_cnt <= 0;
                    end
                end

                ST_STREAM_OUT: begin
                    m_axis_res_tvalid <= 1'b1;
                    m_axis_res_tdata  <= res_dout;
                    res_addr          <= r_cnt + 1;
                    if (m_axis_res_tready) begin
                        r_cnt <= r_cnt + 1;
                        if (r_cnt == reg_n_i - 1) begin
                            m_axis_res_tlast  <= 1'b1;
                            core_done_o       <= 1'b1;
                            state             <= ST_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    integer ri;
    always @(*) begin
        for (ri = 0; ri < ROWS; ri = ri + 1)
            row_in_r[ri] = (state == ST_FEED) ? 8'h01 : 8'h00; // simple test feed
    end

endmodule
