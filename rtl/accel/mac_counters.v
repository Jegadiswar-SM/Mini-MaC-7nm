module mac_counters (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cnt_en,
    input  wire        cnt_rst,
    input  wire [7:0]  max_val,
    output reg  [10:0] addr_o,
    output wire        done_o
);
    reg [7:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || cnt_rst) begin
            count <= 8'd0;
        end else if (cnt_en) begin
            if (count < max_val - 1)
                count <= count + 1'b1;
        end
    end

    assign addr_o = {3'd0, count}; // Map to 11-bit SRAM addr
    assign done_o = (count == max_val - 1);
endmodule
