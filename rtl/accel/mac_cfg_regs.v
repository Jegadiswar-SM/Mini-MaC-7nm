/* verilator lint_off UNUSEDSIGNAL */
// =============================================================================
// mac_cfg_regs.v — APB Configuration Register File (Upgraded MAC Accelerator)
// =============================================================================
// APB is used STRICTLY for control/config. Data travels via AXI4-Stream DMA.
//
// Register Map (CPU sees offset from s_psel[1] base = 0x40011000):
//   0x00  CTRL         WO  start[0] (W1, auto-clears), abort[1] (W1, auto-clears)
//   0x04  STATUS       RO  busy[0], done[1] (sticky, W1C on bit[1] write)
//   0x08  DIM          RW  M[23:16]=out_rows, K[15:8]=reduction_k, N[7:0]=out_cols
//   0x0C  BIAS_EN      RW  bias_enable[0], bias_scale[15:8]  (stub, reserved)
//   0x10  CORE_EN      RW  core_en[3:0]   (per-core enable mask)
//   0x20  WGT_BASE     RW  system SRAM byte address for weight data
//   0x24  ACT_BASE     RW  system SRAM byte address for activation data
//   0x28  RES_BASE     RW  system SRAM byte address for result write-back
//   0x2C  DMA_LEN_WGT  RW  byte count for weight DMA fill
//   0x30  DMA_LEN_ACT  RW  byte count for activation DMA fill
//   0x34  DMA_STATUS   RO  wgt_done[0], act_done[1], res_done[2]
// =============================================================================
module mac_cfg_regs (
    input  wire        clk,
    input  wire        rst_n,

    // APB slave
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,

    // Control outputs → DMA engine / core orchestrator
    output reg         start_o,        // single-cycle pulse
    output reg         abort_o,        // single-cycle pulse
    output reg  [7:0]  dim_m_o,
    output reg  [7:0]  dim_k_o,
    output reg  [7:0]  dim_n_o,
    output reg  [3:0]  core_en_o,
    output reg  [31:0] wgt_base_o,
    output reg  [31:0] act_base_o,
    output reg  [31:0] res_base_o,
    output reg  [31:0] dma_len_wgt_o,
    output reg  [31:0] dma_len_act_o,

    // Status inputs ← DMA engine / core
    input  wire        busy_i,         // asserted from start until DMA res drain done
    input  wire        done_i,         // single-cycle pulse: all done (sets sticky)
    input  wire        wgt_done_i,
    input  wire        act_done_i,
    input  wire        res_done_i
);

    assign pready = 1'b1;   // zero-wait-state APB slave

    reg sticky_done;

    // -------------------------------------------------------------------------
    // Register write logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_o        <= 1'b0;
            abort_o        <= 1'b0;
            dim_m_o        <= 8'd4;
            dim_k_o        <= 8'd4;
            dim_n_o        <= 8'd4;
            core_en_o      <= 4'b1111;
            wgt_base_o     <= 32'h1000_0000;
            act_base_o     <= 32'h1000_1000;
            res_base_o     <= 32'h1000_2000;
            dma_len_wgt_o  <= 32'd16;
            dma_len_act_o  <= 32'd16;
            sticky_done    <= 1'b0;
        end else begin
            start_o <= 1'b0;    // auto-clear each cycle
            abort_o <= 1'b0;

            if (done_i)
                sticky_done <= 1'b1;

            if (psel && penable && pwrite) begin
                case (paddr[7:0])
                    8'h00: begin
                        if (pwdata[0]) begin
                            start_o     <= 1'b1;
                            sticky_done <= 1'b0;  // clear done on re-start
                        end
                        if (pwdata[1]) abort_o <= 1'b1;
                    end
                    8'h04: if (pwdata[1]) sticky_done <= 1'b0;  // W1C done flag
                    8'h08: {dim_m_o, dim_k_o, dim_n_o} <= pwdata[23:0];
                    // 0x0C BIAS_EN: stub, no write logic
                    8'h10: core_en_o      <= pwdata[3:0];
                    8'h20: wgt_base_o     <= pwdata;
                    8'h24: act_base_o     <= pwdata;
                    8'h28: res_base_o     <= pwdata;
                    8'h2C: dma_len_wgt_o  <= pwdata;
                    8'h30: dma_len_act_o  <= pwdata;
                    default: ;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // Register read logic
    // -------------------------------------------------------------------------
    always @(*) begin
        case (paddr[7:0])
            8'h00: prdata = 32'h0;                              // CTRL: write-only
            8'h04: prdata = {30'h0, sticky_done, busy_i};      // STATUS
            8'h08: prdata = {8'h0, dim_m_o, dim_k_o, dim_n_o}; // DIM
            8'h0C: prdata = 32'h0;                              // BIAS_EN: stub
            8'h10: prdata = {28'h0, core_en_o};                 // CORE_EN
            8'h20: prdata = wgt_base_o;
            8'h24: prdata = act_base_o;
            8'h28: prdata = res_base_o;
            8'h2C: prdata = dma_len_wgt_o;
            8'h30: prdata = dma_len_act_o;
            8'h34: prdata = {29'h0, res_done_i, act_done_i, wgt_done_i}; // DMA_STATUS
            default: prdata = 32'h0;
        endcase
    end

endmodule
