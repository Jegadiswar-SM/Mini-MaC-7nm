module sanity_check (
    input wire clk,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [15:0] prod
);
    always @(posedge clk) begin
        prod <= a * b;
    end
endmodule
