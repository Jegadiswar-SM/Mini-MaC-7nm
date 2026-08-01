module obi_to_apb (
    input  wire        clk,
    input  wire        rst_n,

    // OBI Port
    input  wire        obi_req,
    output wire        obi_gnt,    // Combinational fix
    input  wire [31:0] obi_addr,
    input  wire        obi_we,
    input  wire [31:0] obi_wdata,
    output reg         obi_rvalid,
    output wire [31:0] obi_rdata,

    // APB Port
    output reg  [31:0] paddr,
    output reg         psel,
    output reg         penable,
    output reg         pwrite,
    output reg  [31:0] pwdata,
    input  wire [31:0] prdata,
    input  wire        pready
);

    localparam [1:0]
        ST_IDLE  = 2'd0,
        ST_SETUP = 2'd1,
        ST_ACCESS= 2'd2;
    reg [1:0] state;

    // CPU always gets an immediate grant if we are idle
    assign obi_gnt = (state == ST_IDLE) && obi_req;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            psel <= 0; penable <= 0; obi_rvalid <= 0;
        end else begin
            case (state)
                ST_IDLE: begin
                    obi_rvalid <= 0;
                    if (obi_req) begin
                        paddr  <= obi_addr;
                        pwrite <= obi_we;
                        pwdata <= obi_wdata;
                        psel   <= 1;
                        state  <= ST_SETUP;
                    end
                end
                ST_SETUP: begin
                    penable <= 1;
                    state   <= ST_ACCESS;
                end
                ST_ACCESS: begin
                    if (pready) begin
                        psel <= 0;
                        penable <= 0;
                        obi_rvalid <= 1;
                        state <= ST_IDLE;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
    assign obi_rdata = prdata;
endmodule
