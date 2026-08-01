module boot_rom (
    input  wire        clk,
    input  wire [9:0]  addr, // 1024 words = 4KB
    output reg  [31:0] rdata
);
    reg [31:0] rom [0:1023];

`ifdef SYNTHESIS
    // For synthesis: ROM initialized to zero (must be replaced with actual
    // firmware content or foundry ROM macro before tapeout)
    integer _i;
    initial begin
        for (_i = 0; _i < 1024; _i = _i + 1)
            rom[_i] = 32'h0;
    end
`else
    // During simulation, we load the firmware here
    initial begin
        $readmemh("firmware.hex", rom);
    end
`endif

    always @(posedge clk) begin
        rdata <= rom[addr];
    end
endmodule
