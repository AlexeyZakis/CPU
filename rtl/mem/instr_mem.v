import cpu_defs::*;

module instr_mem (
    input wire [ADDR_W-1:0] addr,
    output wire [INSTR_W-1:0] rdata
);
    reg [INSTR_W-1:0] mem [0:IMEM_DEPTH-1];
    integer i;

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

    initial begin
        for (i = 0; i < IMEM_DEPTH; i = i + 1) begin
            mem[i] = 0;
        end

        mem[0] = enc_i(OPC_ADDI, 5'd0, 5'd1, 16'd10);      // 0:  addi r1, r0, 10      ; r1 = A (10)
        mem[1] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd0);         // 1:  sw   r1, 0(r0)       ; MEM[0] = A (10)
        mem[2] = enc_i(OPC_LW, 5'd0, 5'd2, 16'd0);         // 2:  lw   r2, 0(r0)       ; r2 = MEM[0] = A (10)

        mem[3] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);       // 3:  addi r1, r1, 1       ; r1 = B (11)
        mem[4] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd4);         // 4:  sw   r1, 4(r0)       ; MEM[1] = B (11)
        mem[5] = enc_i(OPC_LW, 5'd0, 5'd3, 16'd4);         // 5:  lw   r3, 4(r0)       ; r3 = MEM[1] = B (11)

        mem[6] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);       // 6:  addi r1, r1, 1       ; r1 = C (12)
        mem[7] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd8);         // 7:  sw   r1, 8(r0)       ; MEM[2] = C (12)
        mem[8] = enc_i(OPC_LW, 5'd0, 5'd4, 16'd8);         // 8:  lw   r4, 8(r0)       ; r4 = MEM[2] = C (12)

        mem[9] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);       // 9:  addi r1, r1, 1       ; r1 = D (13)
        mem[10] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd12);       // 10: sw   r1, 12(r0)      ; MEM[3] = D (13)
        mem[11] = enc_i(OPC_LW, 5'd0, 5'd5, 16'd12);       // 11: lw   r5, 12(r0)      ; r5 = MEM[3] = D (13)

        mem[12] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);      // 12: addi r1, r1, 1       ; r1 = E (14)
        mem[13] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd16);       // 13: sw   r1, 16(r0)      ; MEM[4] = E (14)
        mem[14] = enc_i(OPC_LW, 5'd0, 5'd6, 16'd16);       // 14: lw   r6, 16(r0)      ; r6 = MEM[4] = E (14)

        mem[15] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);      // 15: addi r1, r1, 1       ; r1 = F (15)
        mem[16] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd20);       // 16: sw   r1, 20(r0)      ; MEM[5] = F (15)
        mem[17] = enc_i(OPC_LW, 5'd0, 5'd7, 16'd20);       // 17: lw   r7, 20(r0)      ; r7 = MEM[5] = F (15)

        mem[18] = enc_i(OPC_LW, 5'd0, 5'd2, 16'd0);        // 18: lw   r2, 0(r0)       ; r2 = MEM[0] = A (10)
        mem[19] = enc_r(5'd2, 5'd3, 5'd3, FUNCT_ADD);      // 19: add  r3, r2, r3      ; r3 = A + B = 15 (21)
        mem[20] = enc_r(5'd4, 5'd5, 5'd4, FUNCT_ADD);      // 20: add  r4, r4, r5      ; r4 = C + D = 19 (25)
        mem[21] = enc_r(5'd6, 5'd7, 5'd6, FUNCT_ADD);      // 21: add  r6, r6, r7      ; r6 = E + F = 1D (29)

        mem[22] = enc_i(OPC_SW, 5'd0, 5'd6, 16'd24);       // 22: sw   r6, 24(r0)      ; MEM[6] = 1D (29)
        mem[23] = enc_i(OPC_LW, 5'd0, 5'd5, 16'd24);       // 23: lw   r5, 24(r0)      ; r5 = MEM[6] = 1D (29)
        mem[24] = enc_i(OPC_BEQ, 5'd5, 5'd6, 16'd1);       // 24: beq  r5, r6, +1      ; r5 == r6, skip instr[25]
        mem[25] = enc_i(OPC_ADDI, 5'd0, 5'd7, 16'd99);     // 25: addi r7, r0, 99      ; must be skipped, r7 remains F (15)

        mem[26] = enc_j(OPC_J, 26'd26);                    // 26: j    26              ; while true
    end

    assign rdata = mem[addr[IMEM_ADDR_W + BYTE_OFFSET_W - 1 : BYTE_OFFSET_W]];
endmodule

