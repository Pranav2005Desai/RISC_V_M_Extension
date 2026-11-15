module single_cycle_riscv_m (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic [31:0] instruction,
    input  logic [31:0] mem_out,
    output logic [31:0] rs2_data,
    output logic [31:0] alu_out,
    output logic        mem_write,
    output logic        mem_read,
    output logic [2:0]  fn3,
    output logic [6:0]  opcode,
    output logic [31:0] address
);
    logic [31:0] pc_new, wb_data, rs1_data, imm_out, pc_ex_out;
    logic [6:0]  imm11_5;
    logic [2:0]  aluop;
    logic [1:0]  memtoreg;
    logic        fn7_5, branch, alu_src, mux_inp, and_out_ex;
    logic [31:0] wb_data_i, md_result;
    logic        is_muldiv;

    // RV32M: R-type with funct7 = 0000001 writes back the mul/div result
    assign is_muldiv = (instruction[6:0] == 7'b0110011) && (instruction[31:25] == 7'b0000001);
    assign wb_data   = is_muldiv ? md_result : wb_data_i;

    muldiv u_md (
        .fn3(fn3), .rs1_data(rs1_data), .rs2_data(rs2_data), .result(md_result)
    );

    if_stage u_if (
        .clk(clk), .reset(reset), .stall(stall),
        .and_out(and_out_ex), .pc_signed_offset(pc_ex_out),
        .address(address), .pc_new(pc_new)
    );

    id_stage u_id (
        .clk(clk), .reset(reset), .stall(stall),
        .instruction(instruction), .wb_data(wb_data),
        .rs1_data(rs1_data), .rs2_data(rs2_data), .imm_out(imm_out),
        .opcode_out_d(opcode), .imm11_5(imm11_5), .fn3_out_d(fn3), .fn7_5(fn7_5),
        .aluop(aluop), .memtoreg(memtoreg), .branch(branch),
        .mem_write(mem_write), .mem_read(mem_read),
        .alu_src(alu_src), .mux_inp(mux_inp)
    );

    ex_stage u_ex (
        .rs1_data(rs1_data), .rs2_data(rs2_data), .imm_out(imm_out),
        .address(address), .branch(branch), .alu_src(alu_src),
        .fn7_5(fn7_5), .mux_inp(mux_inp), .fn3(fn3), .imm11_5(imm11_5),
        .aluop(aluop), .opcode(opcode),
        .and_out_ex(and_out_ex), .alu_out(alu_out), .pc_ex_out(pc_ex_out)
    );

    wb_stage u_wb (
        .mem_out(mem_out), .alu_out(alu_out), .return_addr(pc_new),
        .imm_out(imm_out), .pc_signed_offset(pc_ex_out),
        .memtoreg(memtoreg), .opcode_out_d(opcode), .wb_data(wb_data_i)
    );
endmodule
