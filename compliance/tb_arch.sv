`timescale 1ns/1ps
// Compliance testbench: one unified little-endian memory at 0x8000_0000 (code + data),
// as riscv-arch-test expects. Stops when the test stores to `tohost`, then writes the
// signature region (one 32-bit word per line) to the file given by +SIG=.
module tb_arch;
    localparam int MEM_BYTES = 1 << 22;          // 4 MiB
    localparam logic [31:0] BASE = 32'h8000_0000;

    logic clk = 0, reset = 1, stall = 0;
    logic [31:0] instruction, mem_out, rs2_data, alu_out, address;
    logic mem_write, mem_read;
    logic [2:0] fn3;
    logic [6:0] opcode;

    single_cycle_riscv_m dut (.*);

    logic [7:0] mem [0:MEM_BYTES-1];
    logic [31:0] sig_begin, sig_end, tohost, max_cycles, cyc;
    string hexfile, sigfile;
    integer f;

    always #5 clk = ~clk;

    function automatic logic [7:0] rd8(input logic [31:0] a);
        logic [31:0] o = a - BASE;
        return (o < MEM_BYTES) ? mem[o[21:0]] : 8'h00;
    endfunction

    assign instruction = {rd8(address + 3), rd8(address + 2), rd8(address + 1), rd8(address)};

    // core does no load extension: memory returns the extended value selected by fn3
    always_comb begin
        case (fn3)
            3'b000:  mem_out = {{24{rd8(alu_out)[7]}}, rd8(alu_out)};
            3'b001:  mem_out = {{16{rd8(alu_out + 1)[7]}}, rd8(alu_out + 1), rd8(alu_out)};
            3'b100:  mem_out = {24'b0, rd8(alu_out)};
            3'b101:  mem_out = {16'b0, rd8(alu_out + 1), rd8(alu_out)};
            default: mem_out = {rd8(alu_out + 3), rd8(alu_out + 2), rd8(alu_out + 1), rd8(alu_out)};
        endcase
    end

    logic [31:0] wo;
    assign wo = alu_out - BASE;
    always_ff @(posedge clk) if (mem_write && !reset && wo < MEM_BYTES) begin
        mem[wo[21:0]] <= rs2_data[7:0];
        if (fn3[1:0] != 2'b00) mem[wo[21:0] + 1] <= rs2_data[15:8];
        if (fn3[1:0] == 2'b10) begin
            mem[wo[21:0] + 2] <= rs2_data[23:16];
            mem[wo[21:0] + 3] <= rs2_data[31:24];
        end
    end

    initial begin
        for (int i = 0; i < MEM_BYTES; i++) mem[i] = 8'h00;
        if (!$value$plusargs("HEX=%s", hexfile))   $fatal(1, "+HEX= required");
        if (!$value$plusargs("SIG=%s", sigfile))   $fatal(1, "+SIG= required");
        if (!$value$plusargs("BEGIN=%h", sig_begin)) $fatal(1, "+BEGIN= required");
        if (!$value$plusargs("END=%h", sig_end))   $fatal(1, "+END= required");
        if (!$value$plusargs("TOHOST=%h", tohost)) $fatal(1, "+TOHOST= required");
        if (!$value$plusargs("MAXCYC=%d", max_cycles)) max_cycles = 2_000_000;
        $readmemh(hexfile, mem);

        repeat (3) @(posedge clk);
        @(negedge clk) reset = 0;
        for (cyc = 0; cyc < max_cycles; cyc++) begin
            @(negedge clk);
            if (mem_write && alu_out == tohost) break;
        end
        if (cyc == max_cycles) $display("TIMEOUT after %0d cycles (pc=%08x)", cyc, address);
        else                   $display("HALT after %0d cycles", cyc);

        f = $fopen(sigfile, "w");
        for (logic [31:0] a = sig_begin; a < sig_end; a += 4)
            $fdisplay(f, "%02x%02x%02x%02x", rd8(a + 3), rd8(a + 2), rd8(a + 1), rd8(a));
        $fclose(f);
        $finish;
    end
endmodule
