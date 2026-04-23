package cpu_defs;

localparam DATA_W = 32;
localparam ADDR_W = 32;

localparam INSTR_W = 32;
localparam IMM_W = 16;

localparam BYTE_W = 8;

localparam REG_COUNT = 8;

localparam DMEM_DEPTH = 128;

localparam IMEM_DEPTH = 64;

localparam L1_BANKS = 2;
localparam L1_WAYS = 2;
localparam L1_SETS_PER_BANK = 2;
localparam L1_LINE_WORDS = 4;
localparam L2_SETS = 8;
localparam WRITE_BUFFER_DEPTH = 4;

// Opcodes (MIPS-like)
localparam OPC_RTYPE = 6'b000000;
localparam OPC_ADDI = 6'b001000;
localparam OPC_BEQ = 6'b000100;
localparam OPC_LW = 6'b100011;
localparam OPC_SW = 6'b101011;
localparam OPC_J = 6'b000010;

// Func codes for R-type
localparam FUNCT_ADD = 6'b100000;
localparam FUNCT_SUB = 6'b100010;
localparam FUNCT_AND = 6'b100100;
localparam FUNCT_OR = 6'b100101;
localparam FUNCT_SLT = 6'b101010;
localparam FUNCT_MUL = 6'b011000;

// ISA field widths
localparam ISA_OPC_W = 6;
localparam ISA_REG_W = 5;
localparam ISA_SHAMT_W = 5;
localparam ISA_FUNCT_W = 6;
localparam ISA_IMM_W = 16;
localparam ISA_JADDR_W = 26;

// MIPS-like instruction field bit positions
localparam OPC_MSB = 31;
localparam OPC_LSB = 26;

localparam RS_MSB = 25;
localparam RS_LSB = 21;

localparam RT_MSB = 20;
localparam RT_LSB = 16;

localparam RD_MSB = 15;
localparam RD_LSB = 11;

localparam SHAMT_MSB = 10;
localparam SHAMT_LSB = 6;

localparam FUNCT_MSB = 5;
localparam FUNCT_LSB = 0;

localparam IMM_MSB = 15;
localparam IMM_LSB = 0;

localparam JADDR_MSB = 25;
localparam JADDR_LSB = 0;

// ALU control
localparam ALU_OP_W = 4;

localparam ALU_NOP = 0;
localparam ALU_ADD = 1;
localparam ALU_SUB = 2;
localparam ALU_AND = 3;
localparam ALU_OR = 4;
localparam ALU_SLT = 5;
localparam ALU_MUL = 6;

// Mul states
localparam [1:0] MUL_STATE_IDLE = 2'b00;
localparam [1:0] MUL_STATE_RUN = 2'b01;
localparam [1:0] MUL_STATE_COMMIT = 2'b10;

// Forward selectors
localparam [1:0] FWD_SEL_REG = 2'b00;
localparam [1:0] FWD_SEL_EX_MEM = 2'b01;
localparam [1:0] FWD_SEL_WB = 2'b10;

// Cache refill states
localparam [1:0] REFILL_IDLE = 2'b00;
localparam [1:0] REFILL_LOOKUP = 2'b01;
localparam [1:0] REFILL_WAIT_MEM = 2'b10;
localparam [1:0] REFILL_COMMIT = 2'b11;

// Pre-calculated constants
localparam REG_ADDR_W = $clog2(REG_COUNT);
localparam DMEM_ADDR_W = $clog2(DMEM_DEPTH);
localparam IMEM_ADDR_W = $clog2(IMEM_DEPTH);

localparam WORD_BYTES = DATA_W / BYTE_W;
localparam BYTE_OFFSET_W = $clog2(WORD_BYTES);
localparam LINE_WORD_IDX_W = $clog2(L1_LINE_WORDS);
localparam L1_TOTAL_SET_W = $clog2(L1_TOTAL_SETS);
localparam L1_TOTAL_SETS = L1_BANKS * L1_SETS_PER_BANK;
localparam L1_BANK_W = $clog2(L1_BANKS);
localparam L1_SET_W = $clog2(L1_SETS_PER_BANK);
localparam L2_SET_W = $clog2(L2_SETS);
localparam WRITE_BUFFER_PTR_W = $clog2(WRITE_BUFFER_DEPTH);

localparam MUL_CNT_W = $clog2(DATA_W + 1);

endpackage

