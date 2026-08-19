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
    // During simulation, run.sh supplies +firmware=<project-relative path>.
    // The parameter keeps standalone simulations deterministic as well.
    parameter FIRMWARE_FILE = "dv/xcelium/firmware.hex";
    reg [8*1024-1:0] firmware_file;
    integer firmware_fd;
    initial begin
        firmware_file = FIRMWARE_FILE;
        if ($value$plusargs("firmware=%s", firmware_file)) begin end
        firmware_fd = $fopen(firmware_file, "r");
        if (firmware_fd == 0) begin
            $error("boot_rom: firmware image '%0s' is missing; pass +firmware=<path>", firmware_file);
            $fatal(1, "boot_rom cannot initialize instruction memory");
        end
        $fclose(firmware_fd);
        $readmemh(firmware_file, rom);
    end
`endif

    always @(posedge clk) begin
        rdata <= rom[addr];
    end
endmodule
