/* verilator lint_off UNUSEDSIGNAL */
// =============================================================================
// axi_stream_dma.v — Internal DMA Engine for Streaming System-to-Local SRAM
// =============================================================================
// Moves weights, activations, and results between system SRAM (via OBI master)
// and localized AXI4-Stream interfaces feeding local buffers.
//
// Dual-channel support:
//   - Channel 0: Read System SRAM → Write AXI-Stream (fill WGT / ACT SRAM)
//   - Channel 1: Read AXI-Stream → Write System SRAM (drain RES SRAM)
// =============================================================================
module axi_stream_dma (
    input  wire        clk,
    input  wire        rst_n,

    // Control/config inputs
    input  wire        start_i,
    input  wire        abort_i,
    input  wire [31:0] wgt_base_i,
    input  wire [31:0] act_base_i,
    input  wire [31:0] res_base_i,
    input  wire [31:0] dma_len_wgt_i,
    input  wire [31:0] dma_len_act_i,

    // Status outputs
    output reg         busy_o,
    output reg         wgt_done_o,
    output reg         act_done_o,
    output reg         res_done_o,

    // OBI master port (to system SRAM wrapper via mem_subsystem)
    output reg         m_req_o,
    input  wire        m_gnt_i,
    output reg  [31:0] m_addr_o,
    output reg         m_we_o,
    output reg  [31:0] m_wdata_o,
    input  wire        m_rvalid_i,
    input  wire [31:0] m_rdata_i,

    // AXI4-Stream Weight Output Master (Channel 0 WGT fill)
    output reg  [31:0] m_axis_wgt_tdata,
    output reg         m_axis_wgt_tvalid,
    input  wire        m_axis_wgt_tready,

    // AXI4-Stream Activation Output Master (Channel 0 ACT fill)
    output reg  [31:0] m_axis_act_tdata,
    output reg         m_axis_act_tvalid,
    input  wire        m_axis_act_tready,

    // AXI4-Stream Result Input Slave (Channel 1 RES drain)
    input  wire [31:0] s_axis_res_tdata,
    input  wire        s_axis_res_tvalid,
    output reg         s_axis_res_tready,
    input  wire        s_axis_res_tlast
);

    localparam [2:0]
        ST_IDLE      = 3'd0,
        ST_FILL_WGT  = 3'd1,
        ST_WGT_WAIT  = 3'd2,
        ST_FILL_ACT  = 3'd3,
        ST_ACT_WAIT  = 3'd4,
        ST_RUN_ARRAY = 3'd5,
        ST_DRAIN_RES = 3'd6,
        ST_RES_WRITE = 3'd7;

    reg [2:0] state;
    reg [31:0] curr_addr;
    reg [31:0] bytes_left;
    reg [31:0] wdata_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= ST_IDLE;
            busy_o            <= 1'b0;
            wgt_done_o        <= 1'b0;
            act_done_o        <= 1'b0;
            res_done_o        <= 1'b0;
            m_req_o           <= 1'b0;
            m_addr_o          <= 32'h0;
            m_we_o            <= 1'b0;
            m_wdata_o         <= 32'h0;
            m_axis_wgt_tdata  <= 32'h0;
            m_axis_wgt_tvalid <= 1'b0;
            m_axis_act_tdata  <= 32'h0;
            m_axis_act_tvalid <= 1'b0;
            s_axis_res_tready <= 1'b0;
        end else if (abort_i) begin
            state             <= ST_IDLE;
            busy_o            <= 1'b0;
            m_req_o           <= 1'b0;
            m_axis_wgt_tvalid <= 1'b0;
            m_axis_act_tvalid <= 1'b0;
            s_axis_res_tready <= 1'b0;
        end else begin
            // Defaults
            m_req_o           <= 1'b0;
            m_axis_wgt_tvalid <= 1'b0;
            m_axis_act_tvalid <= 1'b0;
            s_axis_res_tready <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (start_i) begin
                        busy_o     <= 1'b1;
                        wgt_done_o <= 1'b0;
                        act_done_o <= 1'b0;
                        res_done_o <= 1'b0;
                        curr_addr  <= wgt_base_i;
                        bytes_left <= dma_len_wgt_i;
                        state      <= ST_FILL_WGT;
                    end
                end

                ST_FILL_WGT: begin
                    if (bytes_left == 0) begin
                        wgt_done_o <= 1'b1;
                        curr_addr  <= act_base_i;
                        bytes_left <= dma_len_act_i;
                        state      <= ST_FILL_ACT;
                    end else begin
                        m_req_o  <= 1'b1;
                        m_we_o   <= 1'b0;
                        m_addr_o <= curr_addr;
                        if (m_gnt_i) begin
                            state <= ST_WGT_WAIT;
                        end
                    end
                end

                ST_WGT_WAIT: begin
                    if (m_rvalid_i) begin
                        m_axis_wgt_tdata  <= m_rdata_i;
                        m_axis_wgt_tvalid <= 1'b1;
                        curr_addr         <= curr_addr + 4;
                        bytes_left        <= bytes_left - 4;
                        state             <= ST_FILL_WGT;
                    end
                end

                ST_FILL_ACT: begin
                    if (bytes_left == 0) begin
                        act_done_o <= 1'b1;
                        state      <= ST_RUN_ARRAY;
                    end else begin
                        m_req_o  <= 1'b1;
                        m_we_o   <= 1'b0;
                        m_addr_o <= curr_addr;
                        if (m_gnt_i) begin
                            state <= ST_ACT_WAIT;
                        end
                    end
                end

                ST_ACT_WAIT: begin
                    if (m_rvalid_i) begin
                        m_axis_act_tdata  <= m_rdata_i;
                        m_axis_act_tvalid <= 1'b1;
                        curr_addr         <= curr_addr + 4;
                        bytes_left        <= bytes_left - 4;
                        state             <= ST_FILL_ACT;
                    end
                end

                ST_RUN_ARRAY: begin
                    // Array is running asynchronously; wait for result streaming to begin
                    if (s_axis_res_tvalid) begin
                        curr_addr <= res_base_i;
                        state     <= ST_DRAIN_RES;
                    end
                end

                ST_DRAIN_RES: begin
                    s_axis_res_tready <= 1'b1;
                    if (s_axis_res_tvalid) begin
                        wdata_buf <= s_axis_res_tdata;
                        state     <= ST_RES_WRITE;
                    end
                end

                ST_RES_WRITE: begin
                    m_req_o   <= 1'b1;
                    m_we_o    <= 1'b1;
                    m_addr_o  <= curr_addr;
                    m_wdata_o <= wdata_buf;
                    if (m_gnt_i) begin
                        curr_addr <= curr_addr + 4;
                        if (s_axis_res_tlast) begin
                            res_done_o <= 1'b1;
                            busy_o     <= 1'b0;
                            state      <= ST_IDLE;
                        end else begin
                            state <= ST_DRAIN_RES;
                        end
                    end
                end
            endcase
        end
    end

endmodule
