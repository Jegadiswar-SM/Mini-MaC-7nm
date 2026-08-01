/* verilator lint_off UNUSEDPARAM */
module pe #(
    parameter ROW    = 0,
    parameter COL    = 0,
    parameter DATA_W = 8
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  load_wgt,
    input  wire [DATA_W-1:0]     a_in,
    input  wire [DATA_W-1:0]     w_in,
    input  wire [31:0]           acc_in,
    output reg  [DATA_W-1:0]     a_out,
    output reg  [31:0]           acc_out
);
    localparam MUL_W = DATA_W * 2;

    reg signed [DATA_W-1:0] a_reg;
    reg signed [DATA_W-1:0] w_reg;
    reg signed [MUL_W-1:0]  mul_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg   <= {DATA_W{1'b0}};
            w_reg   <= {DATA_W{1'b0}};
            mul_reg <= {MUL_W{1'b0}};
            a_out   <= {DATA_W{1'b0}};
            acc_out <= 32'd0;
        end else begin
            if (load_wgt)
                w_reg <= w_in;

            a_reg   <= a_in;
            mul_reg <= $signed(a_reg) * $signed(w_reg);
            a_out   <= a_reg;
            acc_out <= acc_in + {{(32-MUL_W){mul_reg[MUL_W-1]}}, mul_reg};
        end
    end

endmodule
