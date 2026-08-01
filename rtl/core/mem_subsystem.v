module mem_subsystem #(
    parameter NUM_MAC_MASTERS = 4
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        instr_req,
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_rdata,
    output logic        instr_rvalid,
    output logic        instr_gnt,

    input  logic        cpu_req,
    input  logic [31:0] cpu_addr,
    input  logic        cpu_we,
    input  logic [3:0]  cpu_be,
    input  logic [31:0] cpu_wdata,
    output logic [31:0] cpu_rdata,
    output logic        cpu_rvalid,

    input  logic        dma_req,
    input  logic [31:0] dma_addr,
    input  logic        dma_we,
    input  logic [31:0] dma_wdata,
    output logic [31:0] dma_rdata,
    output logic        dma_gnt,
    output logic        dma_rvalid,

    input  logic [NUM_MAC_MASTERS-1:0] mac_req,
    input  logic [31:0]                mac_addr  [0:NUM_MAC_MASTERS-1],
    input  logic [NUM_MAC_MASTERS-1:0] mac_we,
    input  logic [31:0]                mac_wdata [0:NUM_MAC_MASTERS-1],
    output logic [31:0]                mac_rdata [0:NUM_MAC_MASTERS-1],
    output logic [NUM_MAC_MASTERS-1:0] mac_gnt,
    output logic [NUM_MAC_MASTERS-1:0] mac_rvalid
);

    localparam NUM_MASTERS = 2 + NUM_MAC_MASTERS;

    logic        arb_req;
    logic [31:0] arb_addr;
    logic        arb_we;
    logic [3:0]  arb_be;
    logic [31:0] arb_wdata;
    logic [31:0] arb_rdata;

    logic sel_rom;
    logic sel_ram;

    assign instr_gnt = instr_req;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            instr_rvalid <= 1'b0;
        else
            instr_rvalid <= instr_req;
    end

    logic [NUM_MAC_MASTERS-1:0] mac_gnt_int;
    assign mac_gnt = mac_gnt_int;

    // Round-robin pointer: advances after every MAC grant
    logic [1:0] mac_rr;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mac_rr <= 2'd0;
        else if (|mac_gnt_int)
            mac_rr <= mac_rr + 2'd1;
    end

    // Round-robin grant: one MAC per cycle, CPU has priority
    always_comb begin
        mac_gnt_int = 4'b0;
        if (!cpu_req) begin
            case (mac_rr)
                2'd0: begin
                    if      (mac_req[0]) mac_gnt_int = 4'b0001;
                    else if (mac_req[1]) mac_gnt_int = 4'b0010;
                    else if (mac_req[2]) mac_gnt_int = 4'b0100;
                    else if (mac_req[3]) mac_gnt_int = 4'b1000;
                end
                2'd1: begin
                    if      (mac_req[1]) mac_gnt_int = 4'b0010;
                    else if (mac_req[2]) mac_gnt_int = 4'b0100;
                    else if (mac_req[3]) mac_gnt_int = 4'b1000;
                    else if (mac_req[0]) mac_gnt_int = 4'b0001;
                end
                2'd2: begin
                    if      (mac_req[2]) mac_gnt_int = 4'b0100;
                    else if (mac_req[3]) mac_gnt_int = 4'b1000;
                    else if (mac_req[0]) mac_gnt_int = 4'b0001;
                    else if (mac_req[1]) mac_gnt_int = 4'b0010;
                end
                default: begin
                    if      (mac_req[3]) mac_gnt_int = 4'b1000;
                    else if (mac_req[0]) mac_gnt_int = 4'b0001;
                    else if (mac_req[1]) mac_gnt_int = 4'b0010;
                    else if (mac_req[2]) mac_gnt_int = 4'b0100;
                end
            endcase
        end
    end

    assign dma_gnt = dma_req && !cpu_req && !(|mac_req);

    logic [NUM_MASTERS-1:0] arb_onehot;

    always_comb begin
        arb_onehot = 0;
        if (cpu_req)
            arb_onehot[0] = 1'b1;
        else if (mac_gnt_int[0])
            arb_onehot[1] = 1'b1;
        else if (mac_gnt_int[1])
            arb_onehot[2] = 1'b1;
        else if (mac_gnt_int[2])
            arb_onehot[3] = 1'b1;
        else if (mac_gnt_int[3])
            arb_onehot[4] = 1'b1;
        else if (dma_req)
            arb_onehot[5] = 1'b1;

        arb_req   = |arb_onehot;
        arb_addr  = 32'h0;
        arb_we    = 1'b0;
        arb_be    = 4'h0;
        arb_wdata = 32'h0;

        if (arb_onehot[0]) begin
            arb_addr  = cpu_addr;
            arb_we    = cpu_we;
            arb_be    = cpu_be;
            arb_wdata = cpu_wdata;
        end else if (arb_onehot[1]) begin
            arb_addr  = mac_addr[0];
            arb_we    = mac_we[0];
            arb_be    = 4'hF;
            arb_wdata = mac_wdata[0];
        end else if (arb_onehot[2]) begin
            arb_addr  = mac_addr[1];
            arb_we    = mac_we[1];
            arb_be    = 4'hF;
            arb_wdata = mac_wdata[1];
        end else if (arb_onehot[3]) begin
            arb_addr  = mac_addr[2];
            arb_we    = mac_we[2];
            arb_be    = 4'hF;
            arb_wdata = mac_wdata[2];
        end else if (arb_onehot[4]) begin
            arb_addr  = mac_addr[3];
            arb_we    = mac_we[3];
            arb_be    = 4'hF;
            arb_wdata = mac_wdata[3];
        end else if (arb_onehot[5]) begin
            arb_addr  = dma_addr;
            arb_we    = dma_we;
            arb_be    = 4'hF;
            arb_wdata = dma_wdata;
        end
    end

    assign sel_rom = (instr_req || (arb_addr[31:12] == 20'h0));
    assign sel_ram = (arb_addr[31:20] == 12'h100);

    boot_rom u_rom (
        .clk(clk),
        .addr(instr_req ? instr_addr[11:2] : arb_addr[11:2]),
        .rdata(instr_rdata)
    );

    logic [31:0] ram_dout;
    sram_wrapper #(.DEPTH(2048)) u_ram (
        .clk(clk),
        .sram_cen(!(sel_ram && arb_req)),
        .sram_wen(!arb_we),
        .sram_addr(arb_addr[12:2]),
        .sram_wmask(arb_be),
        .sram_din(arb_wdata),
        .sram_dout(ram_dout)
    );

    assign arb_rdata = sel_rom ? instr_rdata : ram_dout;
    assign cpu_rdata = arb_rdata;
    assign dma_rdata = ram_dout;

    genvar gr;
    generate
        for (gr = 0; gr < NUM_MAC_MASTERS; gr = gr + 1) begin : gen_mac_rdata
            assign mac_rdata[gr] = ram_dout;
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_rvalid <= 0;
            dma_rvalid <= 0;
            mac_rvalid <= 0;
        end else begin
            cpu_rvalid <= cpu_req;
            dma_rvalid <= dma_gnt;
            mac_rvalid <= mac_gnt;
        end
    end

endmodule
