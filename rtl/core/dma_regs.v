/* verilator lint_off UNUSEDSIGNAL */
module dma_regs (
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave Interface
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,

    // Interface to DMA Logic
    output reg [31:0]  src_addr_o,
    output reg [31:0]  dst_addr_o,
    output reg [15:0]  length_o,
    output reg         start_o,
    output reg         abort_o,
    input  wire        busy_i,
    input  wire        done_i,
    input  wire        err_i,
    output reg         irq_ack_o
);

    assign pready = 1'b1;

    // Offsets from §6.2
    localparam ADDR_SRC     = 8'h00;
    localparam ADDR_DST     = 8'h04;
    localparam ADDR_LEN     = 8'h08;
    localparam ADDR_CTRL    = 8'h0C;
    localparam ADDR_STAT    = 8'h10;
    localparam ADDR_IRQ_ACK = 8'h14;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_addr_o <= 32'h0;
            dst_addr_o <= 32'h0;
            length_o   <= 16'h0;
            start_o    <= 1'b0;
            abort_o    <= 1'b0;
            irq_ack_o  <= 1'b0;
        end else begin
            start_o   <= 1'b0;
            abort_o   <= 1'b0;
            irq_ack_o <= 1'b0;
            
            if (psel && penable && pwrite) begin
                case (paddr[7:0])
                    ADDR_SRC:     src_addr_o <= pwdata;
                    ADDR_DST:     dst_addr_o <= pwdata;
                    ADDR_LEN:     length_o   <= pwdata[15:0];
                    ADDR_CTRL:    begin
                                    start_o <= pwdata[0];
                                    abort_o <= pwdata[1];
                                  end
                    ADDR_IRQ_ACK: irq_ack_o  <= pwdata[0];
                    default:;
                endcase
            end
        end
    end

    always @(*) begin
        case (paddr[7:0])
            ADDR_SRC:  prdata = src_addr_o;
            ADDR_DST:  prdata = dst_addr_o;
            ADDR_LEN:  prdata = {16'h0, length_o};
            ADDR_STAT: prdata = {29'h0, err_i, done_i, busy_i};
            default:   prdata = 32'h0;
        endcase
    end
endmodule
