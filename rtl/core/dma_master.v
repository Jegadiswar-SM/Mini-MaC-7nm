module dma_master (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [31:0] src_addr_i,
    input  wire [31:0] dst_addr_i,
    input  wire [15:0] length_i,
    input  wire        start_i,
    output reg         busy_o,
    output reg         done_o,
    output reg         err_o,

    output reg         req_o,
    input  wire        gnt_i,
    output reg  [31:0] addr_o,
    output reg         we_o,
    output reg  [31:0] wdata_o,
    input  wire        rvalid_i,
    input  wire [31:0] rdata_i
);

    localparam [2:0]
        ST_IDLE  = 3'd0,
        ST_FETCH = 3'd1,
        ST_WAIT_R= 3'd2,
        ST_STORE = 3'd3,
        ST_DONE  = 3'd4;
    reg [2:0] state;

    reg [31:0] curr_src, curr_dst, data_buffer;
    reg [15:0] bytes_left;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            busy_o <= 0; done_o <= 0; err_o <= 0;
            req_o <= 0;
        end else begin
            case (state)
                ST_IDLE: begin
                    done_o <= 0;
                    if (start_i) begin
                        if (src_addr_i[1:0] != 0 || dst_addr_i[1:0] != 0) begin
                            err_o <= 1;
                        end else begin
                            curr_src   <= src_addr_i;
                            curr_dst   <= dst_addr_i;
                            bytes_left <= length_i;
                            busy_o     <= 1;
                            state      <= ST_FETCH;
                        end
                    end
                end

                ST_FETCH: begin
                    req_o  <= 1;
                    we_o   <= 0;
                    addr_o <= curr_src;
                    if (gnt_i) begin
                        state <= ST_WAIT_R;
                        req_o <= 0;
                    end
                end

                ST_WAIT_R: begin
                    if (rvalid_i) begin
                        data_buffer <= rdata_i;
                        state       <= ST_STORE;
                    end
                end

                ST_STORE: begin
                    req_o   <= 1;
                    we_o    <= 1;
                    addr_o  <= curr_dst;
                    wdata_o <= data_buffer;
                    if (gnt_i) begin
                        req_o <= 0;
                        curr_src <= curr_src + 32'd4;
                        curr_dst <= curr_dst + 32'd4;
                        if (bytes_left <= 16'd4) begin
                            state <= ST_DONE;
                        end else begin
                            bytes_left <= bytes_left - 16'd4;
                            state <= ST_FETCH;
                        end
                    end
                end

                ST_DONE: begin
                    busy_o <= 0;
                    done_o <= 1;
                    state  <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
