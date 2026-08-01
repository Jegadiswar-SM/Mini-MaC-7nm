module systolic_array #(
    parameter ROWS   = 4,
    parameter COLS   = 4,
    parameter DATA_W = 8
) (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      load_wgt,
    input  wire [DATA_W-1:0]         row_in  [0:ROWS-1],
    input  wire [DATA_W-1:0]         w_in    [0:ROWS-1][0:COLS-1],
    input  wire [31:0]               col_in  [0:COLS-1],
    output wire [31:0]               col_out [0:COLS-1]
);
    wire [DATA_W-1:0] h_wire [0:ROWS-1][0:COLS];
    wire [31:0]        v_wire [0:ROWS][0:COLS-1];

    genvar i, j;
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : gen_rows
            assign h_wire[i][0] = row_in[i];
            for (j = 0; j < COLS; j = j + 1) begin : gen_cols
                if (i == 0) begin : gen_col_init
                    assign v_wire[0][j] = col_in[j];
                end
                pe #(.ROW(i), .COL(j), .DATA_W(DATA_W)) u_pe (
                    .clk      (clk),
                    .rst_n    (rst_n),
                    .load_wgt (load_wgt),
                    .a_in     (h_wire[i][j]),
                    .w_in     (w_in[i][j]),
                    .acc_in   (v_wire[i][j]),
                    .a_out    (h_wire[i][j+1]),
                    .acc_out  (v_wire[i+1][j])
                );
            end
        end
    endgenerate

    genvar k;
    generate
        for (k = 0; k < COLS; k = k + 1) begin : gen_outputs
            assign col_out[k] = v_wire[ROWS][k];
        end
    endgenerate
endmodule
