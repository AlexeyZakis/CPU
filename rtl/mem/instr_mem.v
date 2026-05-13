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

        mem[0] = enc_i(OPC_ADDI, 5'd0, 5'd1, 16'd0);              // r1 = 0
        mem[1] = enc_i(OPC_VM_SEG_BASE, 5'd1, 5'd0, 16'd0);       // segment.base = r1 + 0
        mem[2] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd96);             // r2 = 96
        mem[3] = enc_i(OPC_VM_SEG_LIMIT, 5'd2, 5'd0, 16'd0);      // segment.limit = r2 + 0
        mem[4] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd0);              // r2 = physical base 0
        mem[5] = enc_i(OPC_VM_MAP_SMALL, 5'd0, 5'd2, 16'd0);      // small page: V0 -> P0
        mem[6] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd8);              // r2 = physical base 8
        mem[7] = enc_i(OPC_VM_MAP_SMALL, 5'd0, 5'd2, 16'd8);      // small page: V8 -> P8
        mem[8] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd16);             // r2 = physical base 16
        mem[9] = enc_i(OPC_VM_MAP_LARGE, 5'd0, 5'd2, 16'd16);     // large page: V16 -> P16
        mem[10] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd64);            // r2 = physical base 64
        mem[11] = enc_i(OPC_VM_MAP_SMALL, 5'd0, 5'd2, 16'd32);    // non-identity small page: V32 -> P64
        mem[12] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd96);            // r2 = physical base 96
        mem[13] = enc_i(OPC_VM_MAP_LARGE, 5'd0, 5'd2, 16'd48);    // non-identity large page: V48 -> P96
        mem[14] = enc_i(OPC_VM_TLB_INV, 5'd0, 5'd0, 16'd0);       // start data test with empty TLB

        mem[15] = enc_i(OPC_ADDI, 5'd0, 5'd1, 16'd10);            // addi r1, r0, 10
        mem[16] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd0);               // sw r1, 0(r0)
        mem[17] = enc_i(OPC_LW, 5'd0, 5'd2, 16'd0);               // lw r2, 0(r0)

        mem[18] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 11
        mem[19] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd4);               // sw r1, 4(r0)
        mem[20] = enc_i(OPC_LW, 5'd0, 5'd3, 16'd4);               // lw r3, 4(r0)

        mem[21] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 12
        mem[22] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd8);               // sw r1, 8(r0)
        mem[23] = enc_i(OPC_LW, 5'd0, 5'd4, 16'd8);               // lw r4, 8(r0)

        mem[24] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 13
        mem[25] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd12);              // sw r1, 12(r0)
        mem[26] = enc_i(OPC_LW, 5'd0, 5'd5, 16'd12);              // lw r5, 12(r0)

        mem[27] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 14
        mem[28] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd16);              // sw r1, 16(r0)
        mem[29] = enc_i(OPC_LW, 5'd0, 5'd6, 16'd16);              // lw r6, 16(r0)

        mem[30] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 15
        mem[31] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd20);              // sw r1, 20(r0)
        mem[32] = enc_i(OPC_LW, 5'd0, 5'd7, 16'd20);              // lw r7, 20(r0)

        mem[33] = enc_i(OPC_LW, 5'd0, 5'd2, 16'd0);               // r2 = 10
        mem[34] = enc_r(5'd2, 5'd3, 5'd3, FUNCT_ADD);             // r3 = 21
        mem[35] = enc_r(5'd4, 5'd5, 5'd4, FUNCT_ADD);             // r4 = 25
        mem[36] = enc_r(5'd6, 5'd7, 5'd6, FUNCT_ADD);             // r6 = 29

        mem[37] = enc_i(OPC_SW, 5'd0, 5'd6, 16'd24);              // sw r6, 24(r0)
        mem[38] = enc_i(OPC_LW, 5'd0, 5'd5, 16'd24);              // lw r5, 24(r0)
        mem[39] = enc_i(OPC_BEQ, 5'd5, 5'd6, 16'd1);              // skip instr[40]
        mem[40] = enc_i(OPC_ADDI, 5'd0, 5'd7, 16'd99);            // must be skipped

        mem[41] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 16
        mem[42] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd32);              // V32 -> P64: mem[16] = 16
        mem[43] = enc_i(OPC_LW, 5'd0, 5'd2, 16'd32);              // r2 = 16
        mem[44] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 17
        mem[45] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd36);              // V36 -> P68: mem[17] = 17
        mem[46] = enc_i(OPC_LW, 5'd0, 5'd3, 16'd36);              // r3 = 17

        mem[47] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 18
        mem[48] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd48);              // V48 -> P96: mem[24] = 18
        mem[49] = enc_i(OPC_LW, 5'd0, 5'd4, 16'd48);              // r4 = 18
        mem[50] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 19
        mem[51] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd52);              // V52 -> P100: mem[25] = 19
        mem[52] = enc_i(OPC_LW, 5'd0, 5'd5, 16'd52);              // r5 = 19
        mem[53] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 20
        mem[54] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd56);              // V56 -> P104: mem[26] = 20
        mem[55] = enc_i(OPC_LW, 5'd0, 5'd6, 16'd56);              // r6 = 20
        mem[56] = enc_i(OPC_ADDI, 5'd1, 5'd1, 16'd1);             // r1 = 21
        mem[57] = enc_i(OPC_SW, 5'd0, 5'd1, 16'd60);              // V60 -> P108: mem[27] = 21
        mem[58] = enc_i(OPC_LW, 5'd0, 5'd7, 16'd60);              // r7 = 21

        mem[59] = enc_i(OPC_LW, 5'd0, 5'd2, 16'd0);               // refill TLB after replacement, r2 = 10
        mem[60] = enc_i(OPC_BEQ, 5'd7, 5'd1, 16'd1);              // skip instr[61]
        mem[61] = enc_i(OPC_ADDI, 5'd0, 5'd2, 16'd99);            // must be skipped
        mem[62] = enc_j(OPC_J, 26'd62);                           // while true
    end

    assign rdata = mem[addr[IMEM_ADDR_W + BYTE_OFFSET_W - 1 : BYTE_OFFSET_W]];
endmodule

