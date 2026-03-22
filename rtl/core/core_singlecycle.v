import cpu_defs::*;

module core_singlecycle (
    input wire clk,
    input wire rst,
    output wire [ADDR_W-1:0] imem_addr,
    input wire [DATA_W-1:0] imem_data,
    output wire [ADDR_W-1:0] dmem_addr,
    output wire [DATA_W-1:0] dmem_wdata,
    output wire dmem_we,
    input wire [DATA_W-1:0] dmem_rdata
);
    wire [ADDR_W-1:0] pc;
    wire [ADDR_W-1:0] next_pc;
    wire [ADDR_W-1:0] pc_plus_byte_offset;
    wire [DATA_W-1:0] instruction;

    wire [ISA_OPC_W-1:0] opcode;
    wire [ISA_REG_W-1:0] rs;
    wire [ISA_REG_W-1:0] rt;
    wire [ISA_REG_W-1:0] rd;
    wire [ISA_SHAMT_W-1:0] shamt;
    wire [ISA_FUNCT_W-1:0] funct;
    wire [ISA_IMM_W-1:0] imm;
    wire [ISA_JADDR_W-1:0] jaddr;

    wire reg_write;
    wire mem_write;
    wire mem_to_reg;
    wire alu_src;
    wire reg_dst;
    wire branch;
    wire jump;
    wire [ALU_OP_W-1:0] alu_op;

    wire [DATA_W-1:0] rs_data;
    wire [DATA_W-1:0] rt_data;
    wire [DATA_W-1:0] imm_ext;
    wire [DATA_W-1:0] alu_in2;
    wire [DATA_W-1:0] alu_out;
    wire zero;
    wire take_branch;
    wire [ADDR_W-1:0] branch_target;
    wire [ADDR_W-1:0] jump_target;
    wire [DATA_W-1:0] wb_data;
    wire [REG_ADDR_W-1:0] write_reg;

    assign instruction = imem_data;
    assign imem_addr = pc;
    assign pc_plus_byte_offset = pc + WORD_BYTES;
    assign alu_in2 = alu_src ? imm_ext : rt_data;
    assign dmem_addr = alu_out;
    assign dmem_wdata = rt_data;
    assign dmem_we = mem_write;
    assign write_reg = reg_dst ? rd[REG_ADDR_W-1:0] : rt[REG_ADDR_W-1:0];
    assign jump_target = {{(ADDR_W - ISA_JADDR_W - BYTE_OFFSET_W){1'b0}}, jaddr, {BYTE_OFFSET_W{1'b0}}};

    pc_reg u_pc_reg (
        .clk(clk),
        .rst(rst),
        .store(1'b1),
        .pc_in(next_pc),
        .pc_out(pc)
    );

    decoder u_decoder (
        .instruction(instruction),
        .opcode(opcode),
        .rs(rs),
        .rt(rt),
        .rd(rd),
        .shamt(shamt),
        .funct(funct),
        .imm(imm),
        .jaddr(jaddr)
    );

    control_unit u_control (
        .opcode(opcode),
        .funct(funct),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_src(alu_src),
        .reg_dst(reg_dst),
        .branch(branch),
        .jump(jump),
        .alu_op(alu_op)
    );

    regfile u_regfile (
        .clk(clk),
        .rst(rst),
        .raddr1(rs[REG_ADDR_W-1:0]),
		.raddr2(rt[REG_ADDR_W-1:0]),
        .rdata1(rs_data),
        .rdata2(rt_data),
        .we(reg_write),
        .waddr(write_reg),
        .wdata(wb_data)
    );

    imm_ext u_imm_ext (
        .imm_in(imm),
        .imm_out(imm_ext)
    );

    alu u_alu (
        .in1(rs_data),
        .in2(alu_in2),
        .op(alu_op),
        .out(alu_out),
        .zero(zero)
    );

    branch_unit u_branch (
        .pc_plus_byte_offset(pc_plus_byte_offset),
        .imm_ext(imm_ext),
        .branch(branch),
        .zero(zero),
        .take_branch(take_branch),
        .branch_target(branch_target)
    );

    next_pc_mux u_next_pc_mux (
        .pc_plus_byte_offset(pc_plus_byte_offset),
        .branch_target(branch_target),
        .jump_target(jump_target),
        .take_branch(take_branch),
        .jump(jump),
        .next_pc(next_pc)
    );

    writeback_mux u_writeback_mux (
        .alu_result(alu_out),
        .mem_result(dmem_rdata),
        .mem_to_reg(mem_to_reg),
        .wb_data(wb_data)
    );
endmodule

