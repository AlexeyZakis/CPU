import cpu_defs::*;

module decoder (
    input  wire [INSTR_W-1:0] instruction,
    output wire [ISA_OPC_W-1:0] opcode,
    output wire [ISA_REG_W-1:0] rs,
    output wire [ISA_REG_W-1:0] rt,
    output wire [ISA_REG_W-1:0] rd,
    output wire [ISA_SHAMT_W-1:0] shamt,
    output wire [ISA_FUNCT_W-1:0] funct,
    output wire [ISA_IMM_W-1:0] imm,
    output wire [ISA_JADDR_W-1:0] jaddr
);
    assign opcode = instruction[OPC_MSB : OPC_LSB];
    assign rs = instruction[RS_MSB : RS_LSB];
    assign rt = instruction[RT_MSB : RT_LSB];
    assign rd = instruction[RD_MSB : RD_LSB];
    assign shamt = instruction[SHAMT_MSB : SHAMT_LSB];
    assign funct = instruction[FUNCT_MSB : FUNCT_LSB];
    assign imm = instruction[IMM_MSB : IMM_LSB];
    assign jaddr  = instruction[JADDR_MSB : JADDR_LSB];
endmodule

