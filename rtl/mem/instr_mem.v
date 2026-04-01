import cpu_defs::*;

module instr_mem (
    input wire [ADDR_W-1:0] addr,
    output wire [INSTR_W-1:0] rdata
);
    reg [INSTR_W-1:0] mem [0:IMEM_DEPTH-1];
    
    // DEBUG
    wire [INSTR_W-1:0] dbg_inst0 = mem[0];
    wire [INSTR_W-1:0] dbg_inst1 = mem[1];
    wire [INSTR_W-1:0] dbg_inst2 = mem[2];
    wire [INSTR_W-1:0] dbg_inst3 = mem[3];
    wire [INSTR_W-1:0] dbg_inst4 = mem[4];
    wire [INSTR_W-1:0] dbg_inst5 = mem[5];
    wire [INSTR_W-1:0] dbg_inst6 = mem[6];
    wire [INSTR_W-1:0] dbg_inst7 = mem[7];
    wire [INSTR_W-1:0] dbg_inst8 = mem[8];
    wire [INSTR_W-1:0] dbg_inst9 = mem[9];
    wire [INSTR_W-1:0] dbg_inst10 = mem[10];
    wire [INSTR_W-1:0] dbg_inst11 = mem[11];
    wire [INSTR_W-1:0] dbg_inst12 = mem[12];
    wire [INSTR_W-1:0] dbg_inst13 = mem[13];
    wire [INSTR_W-1:0] dbg_inst14 = mem[14];
    wire [INSTR_W-1:0] dbg_inst15 = mem[15];

    function [INSTR_W-1:0] enc_r;
        input [ISA_REG_W-1:0] rs;
        input [ISA_REG_W-1:0] rt;
        input [ISA_REG_W-1:0] rd;
        input [ISA_FUNCT_W-1:0] funct;
        begin
            enc_r = {OPC_RTYPE, rs, rt, rd, {ISA_SHAMT_W{1'b0}}, funct};
        end
    endfunction

    function [INSTR_W-1:0] enc_i;
        input [ISA_OPC_W-1:0] opcode;
        input [ISA_REG_W-1:0] rs;
        input [ISA_REG_W-1:0] rt;
        input [ISA_IMM_W-1:0] imm;
        begin
            enc_i = {opcode, rs, rt, imm};
        end
    endfunction

    function [INSTR_W-1:0] enc_j;
        input [ISA_OPC_W-1:0] opcode;
        input [ISA_JADDR_W-1:0] jaddr;
        begin
            enc_j = {opcode, jaddr};
        end
    endfunction

    integer i;
    initial begin
        for (i = 0; i < IMEM_DEPTH; i = i + 1) begin
            mem[i] = 0;
        end

        // 0:  addi r1, r0, 5       ; r1 = 5 (5)
        // 1:  addi r2, r0, 7       ; r2 = 7 (7)
        // 2:  add  r3, r1, r2      ; r3 = C (12)
        // 3:  sw   r3, 0(r0)       ; m[0] = C (12)
        // 4:  lw   r4, 0(r0)       ; r4 = C (12)
        // 5:  beq  r4, r3, +1      ; skip instruction 6
        // 6:  addi r5, r0, 99      ; must be skipped
        // 7:  j    9               ; jump to instruction 9
        // 8:  addi r6, r0, 77      ; must be skipped
        // 9:  sw   r4, 4(r0)       ; m[1] = C (12)
        // 10: add  r7, r4, r1      ; r7 = 11 (17)
        // 11: addi r1, r0, 5       ; r1 = 1A9 (425)
        // 12: addi r2, r0, 7       ; r2 = 14D (333)
        // 13: mul  r5, r4, r7      ; r5 = 228D5 (141525)
        // 14: add  r6, r0, r5      ; r6 = 228D5 (141525)
        // 15: j    15              ; (while True)
        mem[0] = enc_i(OPC_ADDI, 5'd0, 5'd1, 16'd5);
        mem[1] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd7);
        mem[2] = enc_r(5'd1, 5'd2, 5'd3, FUNCT_ADD);
        mem[3] = enc_i(OPC_SW, 5'd0, 5'd3, 16'd0);
        mem[4] = enc_i(OPC_LW, 5'd0, 5'd4, 16'd0);
        mem[5] = enc_i(OPC_BEQ, 5'd4, 5'd3, 16'd1);
        mem[6] = enc_i(OPC_ADDI, 5'd0, 5'd5, 16'd99);
        mem[7] = enc_j(OPC_J, 26'd9);
        mem[8] = enc_i(OPC_ADDI, 5'd0, 5'd6, 16'd77);
        mem[9] = enc_i(OPC_SW, 5'd0, 5'd4, 16'd4);
        mem[10] = enc_r(5'd4, 5'd1, 5'd7, FUNCT_ADD);
        mem[11] = enc_i(OPC_ADDI, 5'd0, 5'd1, 16'd425);
        mem[12] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd333);
        mem[13] = enc_r(5'd2, 5'd1, 5'd5, FUNCT_MUL);
        mem[14] = enc_r(5'd0, 5'd5, 5'd6, FUNCT_ADD);
        mem[15] = enc_j(OPC_J, 26'd15);
    end

    assign rdata = mem[addr[IMEM_ADDR_W + BYTE_OFFSET_W - 1 : BYTE_OFFSET_W]];
endmodule

