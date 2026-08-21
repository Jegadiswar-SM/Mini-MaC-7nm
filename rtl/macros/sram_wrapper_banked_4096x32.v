// Simulation/preflight wrapper for a logical 4096x32 SRAM built from sixteen
// 256x32 banks.  This does not replace or modify ASAP7 macro collateral.
module sram_wrapper_banked_4096x32 #(
    parameter integer LOGICAL_DEPTH = 4096,
    parameter integer BANK_DEPTH = 256,
    parameter integer BANKS = 16
) (
    input  wire        clk,
    input  wire        sram_cen,
    input  wire        sram_wen,
    input  wire [11:0] sram_addr,
    input  wire [3:0]  sram_wmask,
    input  wire [31:0] sram_din,
    output wire [31:0] sram_dout
);

    initial begin
        if (LOGICAL_DEPTH != 4096 || BANK_DEPTH != 256 || BANKS != 16)
            $fatal(1, "sram_wrapper_banked_4096x32 requires 16 x 256x32 banks");
    end

    wire [31:0] bank_dout [0:BANKS-1];
    genvar b;
    generate
        for (b = 0; b < BANKS; b = b + 1) begin : gen_bank
            wire bank_selected = (sram_addr[11:8] == b[3:0]);
            sram_wrapper #(.DEPTH(BANK_DEPTH), .ADDR_WIDTH(8)) u_bank (
                .clk(clk),
                .sram_cen(sram_cen || !bank_selected),
                .sram_wen(sram_wen),
                .sram_addr(sram_addr[7:0]),
                .sram_wmask(sram_wmask),
                .sram_din(sram_din),
                .sram_dout(bank_dout[b])
            );
        end
    endgenerate

    assign sram_dout = bank_dout[sram_addr[11:8]];
endmodule
