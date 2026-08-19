// Two-client arbiter for the single DMA port exported by mem_subsystem.
// Read responses are routed using the client selected when the read was
// granted, rather than the current request-side selection.
module dma_arbiter (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        stream_req_i,
    input  wire [31:0] stream_addr_i,
    input  wire        stream_we_i,
    input  wire [31:0] stream_wdata_i,
    output wire        stream_gnt_o,
    output wire        stream_rvalid_o,

    input  wire        copy_req_i,
    input  wire [31:0] copy_addr_i,
    input  wire        copy_we_i,
    input  wire [31:0] copy_wdata_i,
    output wire        copy_gnt_o,
    output wire        copy_rvalid_o,

    output wire        mem_req_o,
    output wire [31:0] mem_addr_o,
    output wire        mem_we_o,
    output wire [31:0] mem_wdata_o,
    input  wire        mem_gnt_i,
    input  wire        mem_rvalid_i
);

    reg next_stream_q;
    reg read_owner_stream_q [0:1];
    reg [1:0] read_owner_count_q;
    wire select_stream = stream_req_i && (!copy_req_i || next_stream_q);
    wire selected_we = select_stream ? stream_we_i : copy_we_i;
    wire read_push = mem_req_o && mem_gnt_i && !mem_we_o;
    wire read_pop  = mem_rvalid_i;

    // Each source has at most one read in flight.  Two owner entries therefore
    // cover the only possible overlap while allowing read responses every cycle.
    assign mem_req_o   = (stream_req_i || copy_req_i) &&
                         !(read_owner_count_q == 2 && !selected_we);
    assign mem_addr_o  = select_stream ? stream_addr_i  : copy_addr_i;
    assign mem_we_o    = select_stream ? stream_we_i    : copy_we_i;
    assign mem_wdata_o = select_stream ? stream_wdata_i : copy_wdata_i;

    assign stream_gnt_o    = mem_gnt_i && select_stream;
    assign copy_gnt_o      = mem_gnt_i && !select_stream && copy_req_i;
    assign stream_rvalid_o = mem_rvalid_i && (read_owner_count_q != 0) &&
                              read_owner_stream_q[0];
    assign copy_rvalid_o   = mem_rvalid_i && (read_owner_count_q != 0) &&
                              !read_owner_stream_q[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_stream_q       <= 1'b0;
            read_owner_stream_q[0] <= 1'b0;
            read_owner_stream_q[1] <= 1'b0;
            read_owner_count_q <= 2'd0;
        end else begin
            if (mem_req_o && mem_gnt_i)
                next_stream_q <= !select_stream;

            case ({read_push, read_pop})
                2'b10: begin
                    if (read_owner_count_q == 0)
                        read_owner_stream_q[0] <= select_stream;
                    else
                        read_owner_stream_q[1] <= select_stream;
                    read_owner_count_q <= read_owner_count_q + 1'b1;
                end
                2'b01: begin
                    if (read_owner_count_q > 1)
                        read_owner_stream_q[0] <= read_owner_stream_q[1];
                    read_owner_count_q <= read_owner_count_q - 1'b1;
                end
                2'b11: begin
                    if (read_owner_count_q == 1)
                        read_owner_stream_q[0] <= select_stream;
                    else begin
                        read_owner_stream_q[0] <= read_owner_stream_q[1];
                        read_owner_stream_q[1] <= select_stream;
                    end
                end
                default: begin end
            endcase
        end
    end
endmodule
