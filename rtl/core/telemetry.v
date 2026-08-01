/* verilator lint_off UNUSEDSIGNAL */
module telemetry (
    input  wire        clk,
    input  wire        rst_n,

    // Event Triggers from around the SoC
    input  wire        pe_valid_i,    // From MAC: High when results are valid
    input  wire        dma_stall_i,   // From DMA: High when PREADY is low
    input  wire        acc_ovfl_i,    // From MAC: High on accumulator overflow
    input  wire        pe_active_i,   // From FSM: High during FEED_ARRAY state

    // APB Slave Interface
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready
);

    // 1. Internal Live Counters
    reg [63:0] cycle_count;
    reg [31:0] mac_count;
    reg [31:0] stall_count;
    reg [31:0] ovfl_count;
    reg [31:0] util_count;

    // 2. Snapshot Registers (§10.2 Implementation Note)
    // Used to prevent "torn reads" of the 64-bit cycle counter
    reg [63:0] cycle_snap;
    reg [31:0] mac_snap, stall_snap, ovfl_snap, util_snap;

    // 3. Control Logic
    reg        en;
    wire       snapshot_trigger = (psel && penable && pwrite && (paddr[7:0] == 8'h20));
    wire       reset_trigger    = (psel && penable && pwrite && (paddr[7:0] == 8'h00) && pwdata[1]);

    assign pready = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || reset_trigger) begin
            cycle_count <= 64'd0;
            mac_count   <= 32'd0;
            stall_count <= 32'd0;
            ovfl_count  <= 32'd0;
            util_count  <= 32'd0;
            en          <= 1'b0;
        end else begin
            // Control Enable
            if (psel && penable && pwrite && (paddr[7:0] == 8'h00)) en <= pwdata[0];

            if (en) begin
                cycle_count <= cycle_count + 1'b1;
                if (pe_valid_i)  mac_count   <= mac_count + 16; // 16 MACs per cycle
                if (dma_stall_i) stall_count <= stall_count + 1'b1;
                if (acc_ovfl_i)  ovfl_count  <= ovfl_count + 1'b1;
                if (pe_active_i) util_count  <= util_count + 1'b1;
            end

            // Capture Snapshots atomically
            if (snapshot_trigger) begin
                cycle_snap <= cycle_count;
                mac_snap   <= mac_count;
                stall_snap <= stall_count;
                ovfl_snap  <= ovfl_count;
                util_snap  <= util_count;
            end
        end
    end

    // 4. APB Read Multiplexer
    always @(*) begin
        case (paddr[7:0])
            8'h00: prdata = {31'd0, en};  // bit[0]=enable; reset_trigger is write-only pulse
            8'h04: prdata = cycle_snap[31:0];
            8'h08: prdata = cycle_snap[63:32];
            8'h0C: prdata = mac_snap;
            8'h10: prdata = stall_snap;
            8'h14: prdata = ovfl_snap;
            8'h18: prdata = util_snap;
            default: prdata = 32'h0;
        endcase
    end

endmodule
