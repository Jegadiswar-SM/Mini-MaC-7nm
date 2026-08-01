// ===========================================================================
// sram_wrapper — Behavioral SRAM model for RTL simulation
// ---------------------------------------------------------------------------
// For Genus/Innovus ASIC flow the `ifndef SYNTHESIS guard hides the behavioral
// reg array so Genus treats this as a black-box (port-list only).
// Replace with the foundry SRAM hard macro LEF+LIB for actual P&R.
//
// Interface is compatible with standard memory-compiler SRAM macros:
//   sram_cen   — Chip enable   (active LOW)
//   sram_wen   — Write enable  (active LOW)
//   sram_addr  — Word address
//   sram_wmask — Byte-write mask (active HIGH per byte)
//   sram_din   — Write data
//   sram_dout  — Read data (registered, available next cycle)
// ===========================================================================
module sram_wrapper #(
    parameter ADDR_WIDTH = 11,
    parameter DEPTH      = 2048
)(
    input  wire                  clk,
    input  wire                  sram_cen,
    input  wire                  sram_wen,
    input  wire [ADDR_WIDTH-1:0] sram_addr,
    input  wire [3:0]            sram_wmask,
    input  wire [31:0]           sram_din,
    output reg  [31:0]           sram_dout
);

`ifndef SYNTHESIS
    // -----------------------------------------------------------------
    // Behavioral model — visible to Xcelium / Verilator simulation only.
    // Genus/Innovus never synthesize this block; they see only the ports
    // above and treat the module as a technology black-box.
    // -----------------------------------------------------------------
    reg [31:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (!sram_cen) begin
            if (!sram_wen) begin
                if (sram_wmask[0]) mem[sram_addr][ 7: 0] <= sram_din[ 7: 0];
                if (sram_wmask[1]) mem[sram_addr][15: 8] <= sram_din[15: 8];
                if (sram_wmask[2]) mem[sram_addr][23:16] <= sram_din[23:16];
                if (sram_wmask[3]) mem[sram_addr][31:24] <= sram_din[31:24];
            end
            sram_dout <= mem[sram_addr];
        end
    end
`else
    // -----------------------------------------------------------------
    // Synthesis stub — Genus/Innovus map this to the foundry SRAM macro.
    // sram_dout must be declared as reg above; tie to X so lint is clean.
    // -----------------------------------------------------------------
    initial sram_dout = 32'bx;
`endif

endmodule
