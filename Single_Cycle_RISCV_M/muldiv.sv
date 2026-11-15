// RV32M multiply / divide unit (purely combinational, single cycle).
// Selected by fn3 for R-type instructions with funct7 = 7'b0000001.
module muldiv (
    input  logic [2:0]  fn3,
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    output logic [31:0] result
);
    localparam logic [2:0] MUL = 3'b000, MULH = 3'b001, MULHSU = 3'b010, MULHU = 3'b011,
                           DIV = 3'b100, DIVU = 3'b101, REM    = 3'b110, REMU  = 3'b111;

    // ---------- multiply: 33x33 signed product covers all four variants ----------
    logic        a_sign, b_sign;
    logic [32:0] a_ext, b_ext;
    logic [63:0] product;                             // low 64 bits of the 33x33 product

    assign a_sign  = (fn3 == MULH || fn3 == MULHSU) & rs1_data[31];
    assign b_sign  = (fn3 == MULH) & rs2_data[31];
    assign a_ext   = {a_sign, rs1_data};
    assign b_ext   = {b_sign, rs2_data};
    assign product = $signed({{31{a_ext[32]}}, a_ext}) * $signed({{31{b_ext[32]}}, b_ext});

    // ---------- divide: unsigned core on magnitudes, signs fixed up after ----------
    logic        div_signed, neg_q, neg_r, div_zero, overflow;
    logic [31:0] a_mag, b_mag, q_mag, r_mag, quot, rem;

    assign div_signed = ~fn3[0];                       // DIV, REM
    assign a_mag      = (div_signed & rs1_data[31]) ? -rs1_data : rs1_data;
    assign b_mag      = (div_signed & rs2_data[31]) ? -rs2_data : rs2_data;
    assign div_zero   = (rs2_data == 32'd0);
    assign overflow   = div_signed & (rs1_data == 32'h8000_0000) & (rs2_data == 32'hFFFF_FFFF);
    assign q_mag      = div_zero ? 32'd0 : a_mag / b_mag;
    assign r_mag      = div_zero ? 32'd0 : a_mag % b_mag;
    assign neg_q      = div_signed & (rs1_data[31] ^ rs2_data[31]);
    assign neg_r      = div_signed & rs1_data[31];

    always_comb begin
        if (div_zero) begin                            // spec: q = all ones, r = dividend
            quot = 32'hFFFF_FFFF;
            rem  = rs1_data;
        end else if (overflow) begin                   // spec: q = dividend, r = 0
            quot = 32'h8000_0000;
            rem  = 32'd0;
        end else begin
            quot = neg_q ? -q_mag : q_mag;
            rem  = neg_r ? -r_mag : r_mag;
        end
    end

    always_comb begin
        case (fn3)
            MUL:                  result = product[31:0];
            MULH, MULHSU, MULHU:  result = product[63:32];
            DIV, DIVU:            result = quot;
            REM, REMU:            result = rem;
            default:              result = 32'd0;
        endcase
    end
endmodule
