/* verilator lint_off UNUSEDSIGNAL */
module mem_arbiter (
    // Master 0: CPU (High Priority)
    input  wire        m0_req,
    output wire        m0_gnt,
    input  wire [31:0] m0_addr,
    input  wire        m0_we,
    input  wire [3:0]  m0_be,
    input  wire [31:0] m0_wdata,

    // Master 1: DMA (Low Priority)
    input  wire        m1_req,
    output wire        m1_gnt,
    input  wire [31:0] m1_addr,
    input  wire        m1_we,
    input  wire [31:0] m1_wdata,

    // Output to SRAM Wrapper
    output wire        sram_cen,
    output wire        sram_wen,
    output wire [10:0] sram_addr,
    output wire [3:0]  sram_wmask,
    output wire [31:0] sram_din
);

    // CPU always wins (§6.1)
    assign m0_gnt = m0_req;
    assign m1_gnt = m1_req && !m0_req;

    // Muxing logic
    assign sram_cen   = !(m0_req || m1_gnt);
    assign sram_wen   = m0_req ? !m0_we : !m1_we;
    assign sram_addr  = m0_req ? m0_addr[12:2] : m1_addr[12:2]; // Word aligned
    assign sram_wmask = m0_req ? m0_be : 4'b1111; // DMA always word-aligned (§6.1)
    assign sram_din   = m0_req ? m0_wdata : m1_wdata;

endmodule
