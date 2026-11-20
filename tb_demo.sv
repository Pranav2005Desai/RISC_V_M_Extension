`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.11.2026 23:44:58
// Design Name: 
// Module Name: tb_demo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps
// Small self-contained demo testbench for waveform screenshots in Vivado.
// Runs MUL/MULH/MULHU/DIV/REM/DIVU, divide-by-zero and signed overflow.
module tb_demo;
    logic        clk = 0, reset = 1, stall = 0;
    logic [31:0] instruction, mem_out = 32'd0;
    logic [31:0] rs2_data, alu_out, address;
    logic        mem_write, mem_read;
    logic [2:0]  fn3;
    logic [6:0]  opcode;

    single_cycle_riscv_m dut (.*);

    always #5 clk = ~clk;

    // instruction ROM (word index = (PC - 0x80000000) / 4)
    logic [31:0] imem [0:15];
    initial begin
        for (int i = 0; i < 16; i++) imem[i] = 32'h0000_0013;   // nop
        imem[0]  = 32'hfec00093; // addi x1,x0,-20
        imem[1]  = 32'h00600113; // addi x2,x0,6
        imem[2]  = 32'h022081b3; // mul    x3,x1,x2   -> 0xFFFFFF88 (-120)
        imem[3]  = 32'h02209233; // mulh   x4,x1,x2   -> 0xFFFFFFFF
        imem[4]  = 32'h0220b2b3; // mulhu  x5,x1,x2   -> 0x00000005
        imem[5]  = 32'h0220c333; // div    x6,x1,x2   -> 0xFFFFFFFD (-3)
        imem[6]  = 32'h0220e3b3; // rem    x7,x1,x2   -> 0xFFFFFFFE (-2)
        imem[7]  = 32'h0220d433; // divu   x8,x1,x2   -> 0x2AAAAAA7
        imem[8]  = 32'h0200c4b3; // div    x9,x1,x0   -> 0xFFFFFFFF (div by 0)
        imem[9]  = 32'h0200e533; // rem    x10,x1,x0  -> 0xFFFFFFEC (= x1)
        imem[10] = 32'h800005b7; // lui    x11,0x80000
        imem[11] = 32'hfff00613; // addi   x12,x0,-1
        imem[12] = 32'h02c5c6b3; // div    x13,x11,x12 -> 0x80000000 (overflow)
        imem[13] = 32'h02c5e733; // rem    x14,x11,x12 -> 0x00000000
        imem[14] = 32'h0000006f; // jal x0,0 (spin)
    end

    logic [31:0] idx;
    assign idx         = (address - 32'h8000_0000) >> 2;
    assign instruction = (idx < 16) ? imem[idx[3:0]] : 32'h0000_0013;

    initial begin
        repeat (2) @(posedge clk);
        #1 reset = 0;
        repeat (30) @(posedge clk);
        #1;
        $display("x3  MUL    = %h (exp ffffff88)", dut.u_id.u_regfile.register[3]);
        $display("x4  MULH   = %h (exp ffffffff)", dut.u_id.u_regfile.register[4]);
        $display("x5  MULHU  = %h (exp 00000005)", dut.u_id.u_regfile.register[5]);
        $display("x6  DIV    = %h (exp fffffffd)", dut.u_id.u_regfile.register[6]);
        $display("x7  REM    = %h (exp fffffffe)", dut.u_id.u_regfile.register[7]);
        $display("x8  DIVU   = %h (exp 2aaaaaa7)", dut.u_id.u_regfile.register[8]);
        $display("x9  DIV/0  = %h (exp ffffffff)", dut.u_id.u_regfile.register[9]);
        $display("x10 REM/0  = %h (exp ffffffec)", dut.u_id.u_regfile.register[10]);
        $display("x13 OVF q  = %h (exp 80000000)", dut.u_id.u_regfile.register[13]);
        $display("x14 OVF r  = %h (exp 00000000)", dut.u_id.u_regfile.register[14]);
        $finish;
    end
endmodule
