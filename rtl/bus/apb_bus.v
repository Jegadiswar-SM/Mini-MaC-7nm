/* verilator lint_off UNUSEDSIGNAL */
module apb_bus (
    // Master Interface (from CPU Bridge)
    input  wire [31:0] m_paddr,
    input  wire        m_psel,
    input  wire        m_penable,
    input  wire        m_pwrite,
    input  wire [31:0] m_pwdata,
    output reg  [31:0] m_prdata,
    output reg         m_pready,

    // Slave Interfaces (to Peripherals)
    // 0: DMA, 1: MAC, 2: TELM, 3: UART, 4: GPIO, 5: SPI
    output reg  [5:0]  s_psel,
    input  wire [31:0] s0_prdata, input wire s0_pready,
    input  wire [31:0] s1_prdata, input wire s1_pready,
    input  wire [31:0] s2_prdata, input wire s2_pready,
    input  wire [31:0] s3_prdata, input wire s3_pready,
    input  wire [31:0] s4_prdata, input wire s4_pready,
    input  wire [31:0] s5_prdata, input wire s5_pready
);

    // Address Decoding Logic (§12.3)
    always @(*) begin
        s_psel = 6'b000000;
        if (m_psel) begin
            case (m_paddr[15:12])
                4'h0: s_psel[0] = 1'b1; // 0x4000: DMA
                4'h1: s_psel[1] = 1'b1; // 0x4001: MAC
                4'h2: s_psel[2] = 1'b1; // 0x4002: TELM
                4'h3: s_psel[3] = 1'b1; // 0x4003: UART
                4'h4: s_psel[4] = 1'b1; // 0x4004: GPIO
                4'h5: s_psel[5] = 1'b1; // 0x4005: SPI
                default: s_psel = 6'b000000;
            endcase
        end
    end

    // Response Multiplexer
    always @(*) begin
        m_pready = 1'b1;
        case (s_psel)
            6'b000001: m_prdata = s0_prdata;
            6'b000010: m_prdata = s1_prdata;
            6'b000100: m_prdata = s2_prdata;
            6'b001000: begin m_prdata = s3_prdata; m_pready = s3_pready; end
            6'b010000: begin m_prdata = s4_prdata; m_pready = s4_pready; end
            6'b100000: begin m_prdata = s5_prdata; m_pready = s5_pready; end
            default:   m_prdata = 32'h0;
        endcase
    end
endmodule
