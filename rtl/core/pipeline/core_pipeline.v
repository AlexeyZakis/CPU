import cpu_defs::*;

module core_pipeline (
    input wire clk,
    input wire rst,
    output wire [ADDR_W-1:0] imem_addr,
    input wire [INSTR_W-1:0] imem_data,
    output wire dcache_req_valid,
    input wire dcache_req_ready,
    output wire dcache_req_write,
    output wire [ADDR_W-1:0] dcache_req_addr,
    output wire [DATA_W-1:0] dcache_req_wdata,
    input wire dcache_resp_valid,
    input wire [DATA_W-1:0] dcache_resp_rdata
);
    wire [ADDR_W-1:0] pc;
    wire [ADDR_W-1:0] pc_next_seq;
    wire [ADDR_W-1:0] pc_next;
    wire pc_store;

    wire [ADDR_W-1:0] if_id_pc;
    wire [INSTR_W-1:0] if_id_instr;
    wire if_id_valid;

    wire [ISA_OPC_W-1:0] id_opcode;
    wire [ISA_REG_W-1:0] id_rs;
    wire [ISA_REG_W-1:0] id_rt;
    wire [ISA_REG_W-1:0] id_rd;
    wire [ISA_SHAMT_W-1:0] id_shamt;
    wire [ISA_FUNCT_W-1:0] id_funct;
    wire [ISA_IMM_W-1:0] id_imm;
    wire [ISA_JADDR_W-1:0] id_jaddr;
    wire id_reg_write;
    wire id_mem_write;
    wire id_mem_read;
    wire id_mem_to_reg;
    wire id_alu_src;
    wire id_reg_dst;
    wire id_branch;
    wire id_jump;
    wire id_is_mul;
    wire [ALU_OP_W-1:0] id_alu_op;
    wire [DATA_W-1:0] id_rs_data;
    wire [DATA_W-1:0] id_rt_data;
    wire [DATA_W-1:0] id_imm_ext;
    wire [REG_ADDR_W-1:0] id_rs_idx;
    wire [REG_ADDR_W-1:0] id_rt_idx;
    wire [REG_ADDR_W-1:0] id_rd_idx;
    wire [REG_ADDR_W-1:0] id_dest_idx;

    wire [ADDR_W-1:0] id_ex_pc;
    wire [DATA_W-1:0] id_ex_rs_data;
    wire [DATA_W-1:0] id_ex_rt_data;
    wire [DATA_W-1:0] id_ex_imm_ext;
    wire [REG_ADDR_W-1:0] id_ex_rs;
    wire [REG_ADDR_W-1:0] id_ex_rt;
    wire [REG_ADDR_W-1:0] id_ex_rd;
    wire [REG_ADDR_W-1:0] id_ex_dest;
    wire [ISA_JADDR_W-1:0] id_ex_jaddr;
    wire id_ex_valid;
    wire id_ex_reg_write;
    wire id_ex_mem_write;
    wire id_ex_mem_read;
    wire id_ex_mem_to_reg;
    wire id_ex_alu_src;
    wire id_ex_branch;
    wire id_ex_jump;
    wire id_ex_is_mul;
    wire [ALU_OP_W-1:0] id_ex_alu_op;

    wire [DATA_W-1:0] ex_mem_alu_out;
    wire [DATA_W-1:0] ex_mem_rt_fwd;
    wire [REG_ADDR_W-1:0] ex_mem_dest;
    wire ex_mem_valid;
    wire ex_mem_reg_write;
    wire ex_mem_mem_write;
    wire ex_mem_mem_read;
    wire ex_mem_mem_to_reg;

    wire [DATA_W-1:0] mem_wb_alu_out;
    wire [DATA_W-1:0] mem_wb_mem_data;
    wire [REG_ADDR_W-1:0] mem_wb_dest;
    wire mem_wb_valid;
    wire mem_wb_reg_write;
    wire mem_wb_mem_to_reg;
    wire [DATA_W-1:0] wb_data;

    wire stall_if;
    wire stall_id;
    wire flush_id_ex;
    wire ex_busy;
    wire mem_stall;
    wire [1:0] fwd_a_sel;
    wire [1:0] fwd_b_sel;
    wire ex_redirect;
    wire [ADDR_W-1:0] ex_redirect_target;
    wire [DATA_W-1:0] ex_rt_fwd;
    wire [DATA_W-1:0] ex_alu_result;
    wire [REG_ADDR_W-1:0] ex_dest;
    wire ex_valid;
    wire ex_reg_write;
    wire ex_mem_write;
    wire ex_mem_read;
    wire ex_mem_to_reg;
    wire [ADDR_W-1:0] ex_pc_target;

    wire [DATA_W-1:0] mem_stage_alu_out;
    wire [DATA_W-1:0] mem_stage_mem_data;
    wire [REG_ADDR_W-1:0] mem_stage_dest;
    wire mem_stage_valid;
    wire mem_stage_reg_write;
    wire mem_stage_mem_to_reg;

    assign pc_next_seq = pc + WORD_BYTES;
    assign pc_next = ex_redirect ? ex_redirect_target : pc_next_seq;
    assign pc_store = ex_redirect || !stall_if;
    assign imem_addr = pc;
    assign wb_data = mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_out;

    assign id_rs_idx = id_rs[REG_ADDR_W-1:0];
    assign id_rt_idx = id_rt[REG_ADDR_W-1:0];
    assign id_rd_idx = id_rd[REG_ADDR_W-1:0];
    assign id_dest_idx = id_reg_dst ? id_rd_idx : id_rt_idx;

    pc_reg u_pc_reg (
        .clk(clk),
        .rst(rst),
        .store(pc_store),
        .pc_in(pc_next),
        .pc_out(pc)
    );

    if_id_reg u_if_id_reg (
        .clk(clk),
        .rst(rst),
        .stall(stall_if),
        .flush(ex_redirect),
        .pc_in(pc),
        .instr_in(imem_data),
        .valid_in(1'b1),
        .pc_out(if_id_pc),
        .instr_out(if_id_instr),
        .valid_out(if_id_valid)
    );

    decoder u_decoder (
        .instruction(if_id_instr),
        .opcode(id_opcode),
        .rs(id_rs),
        .rt(id_rt),
        .rd(id_rd),
        .shamt(id_shamt),
        .funct(id_funct),
        .imm(id_imm),
        .jaddr(id_jaddr)
    );

    control_unit u_control (
        .opcode(id_opcode),
        .funct(id_funct),
        .reg_write(id_reg_write),
        .mem_write(id_mem_write),
        .mem_read(id_mem_read),
        .mem_to_reg(id_mem_to_reg),
        .alu_src(id_alu_src),
        .reg_dst(id_reg_dst),
        .branch(id_branch),
        .jump(id_jump),
        .is_mul(id_is_mul),
        .alu_op(id_alu_op)
    );

    regfile u_regfile (
        .clk(clk),
        .rst(rst),
        .raddr1(id_rs_idx),
        .raddr2(id_rt_idx),
        .rdata1(id_rs_data),
        .rdata2(id_rt_data),
        .we(mem_wb_valid && mem_wb_reg_write),
        .waddr(mem_wb_dest),
        .wdata(wb_data)
    );

    imm_ext u_imm_ext (
        .imm_in(id_imm),
        .imm_out(id_imm_ext)
    );

    hazard_unit u_hazard (
        .id_ex_mem_read(id_ex_valid && id_ex_mem_read),
        .id_ex_dest(id_ex_dest),
        .if_id_rs(id_rs_idx),
        .if_id_rt(id_rt_idx),
        .ex_busy(ex_busy),
        .mem_stall(mem_stall),
        .stall_if(stall_if),
        .stall_id(stall_id),
        .flush_id_ex(flush_id_ex)
    );

    id_ex_reg u_id_ex_reg (
        .clk(clk),
        .rst(rst),
        .stall(stall_id),
        .flush(ex_redirect || flush_id_ex),
        .pc_in(if_id_pc),
        .rs_data_in(id_rs_data),
        .rt_data_in(id_rt_data),
        .imm_ext_in(id_imm_ext),
        .rs_in(id_rs_idx),
        .rt_in(id_rt_idx),
        .rd_in(id_rd_idx),
        .dest_in(id_dest_idx),
        .jaddr_in(id_jaddr),
        .valid_in(if_id_valid),
        .reg_write_in(id_reg_write),
        .mem_write_in(id_mem_write),
        .mem_read_in(id_mem_read),
        .mem_to_reg_in(id_mem_to_reg),
        .alu_src_in(id_alu_src),
        .branch_in(id_branch),
        .jump_in(id_jump),
        .is_mul_in(id_is_mul),
        .alu_op_in(id_alu_op),
        .pc_out(id_ex_pc),
        .rs_data_out(id_ex_rs_data),
        .rt_data_out(id_ex_rt_data),
        .imm_ext_out(id_ex_imm_ext),
        .rs_out(id_ex_rs),
        .rt_out(id_ex_rt),
        .rd_out(id_ex_rd),
        .dest_out(id_ex_dest),
        .jaddr_out(id_ex_jaddr),
        .valid_out(id_ex_valid),
        .reg_write_out(id_ex_reg_write),
        .mem_write_out(id_ex_mem_write),
        .mem_read_out(id_ex_mem_read),
        .mem_to_reg_out(id_ex_mem_to_reg),
        .alu_src_out(id_ex_alu_src),
        .branch_out(id_ex_branch),
        .jump_out(id_ex_jump),
        .is_mul_out(id_ex_is_mul),
        .alu_op_out(id_ex_alu_op)
    );

    forwarding_unit u_fwd (
        .id_ex_rs(id_ex_rs),
        .id_ex_rt(id_ex_rt),
        .ex_mem_reg_write(ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_to_reg),
        .ex_mem_dest(ex_mem_dest),
        .mem_wb_reg_write(mem_wb_valid && mem_wb_reg_write),
        .mem_wb_dest(mem_wb_dest),
        .fwd_a_sel(fwd_a_sel),
        .fwd_b_sel(fwd_b_sel)
    );

    ex_stage u_ex_stage (
        .clk(clk),
        .rst(rst),
        .pc_in(id_ex_pc),
        .rs_data_in(id_ex_rs_data),
        .rt_data_in(id_ex_rt_data),
        .imm_ext_in(id_ex_imm_ext),
        .dest_in(id_ex_dest),
        .jaddr_in(id_ex_jaddr),
        .valid_in(id_ex_valid),
        .reg_write_in(id_ex_reg_write),
        .mem_write_in(id_ex_mem_write),
        .mem_read_in(id_ex_mem_read),
        .mem_to_reg_in(id_ex_mem_to_reg),
        .alu_src_in(id_ex_alu_src),
        .branch_in(id_ex_branch),
        .jump_in(id_ex_jump),
        .is_mul_in(id_ex_is_mul),
        .alu_op_in(id_ex_alu_op),
        .fwd_a_sel(fwd_a_sel),
        .fwd_b_sel(fwd_b_sel),
        .ex_mem_alu_out(ex_mem_alu_out),
        .wb_data(wb_data),
        .busy_out(ex_busy),
        .redirect_out(ex_redirect),
        .redirect_target_out(ex_redirect_target),
        .rt_fwd_out(ex_rt_fwd),
        .alu_out_out(ex_alu_result),
        .dest_out(ex_dest),
        .valid_out(ex_valid),
        .reg_write_out(ex_reg_write),
        .mem_write_out(ex_mem_write),
        .mem_read_out(ex_mem_read),
        .mem_to_reg_out(ex_mem_to_reg),
        .pc_target_out(ex_pc_target)
    );

    ex_mem_reg u_ex_mem_reg (
        .clk(clk),
        .rst(rst),
        .stall(mem_stall),
        .alu_out_in(ex_alu_result),
        .rt_fwd_in(ex_rt_fwd),
        .dest_in(ex_dest),
        .valid_in(ex_valid),
        .reg_write_in(ex_reg_write),
        .mem_write_in(ex_mem_write),
        .mem_read_in(ex_mem_read),
        .mem_to_reg_in(ex_mem_to_reg),
        .alu_out_out(ex_mem_alu_out),
        .rt_fwd_out(ex_mem_rt_fwd),
        .dest_out(ex_mem_dest),
        .valid_out(ex_mem_valid),
        .reg_write_out(ex_mem_reg_write),
        .mem_write_out(ex_mem_mem_write),
        .mem_read_out(ex_mem_mem_read),
        .mem_to_reg_out(ex_mem_mem_to_reg)
    );

    mem_stage u_mem_stage (
        .clk(clk),
        .rst(rst),
        .alu_out_in(ex_mem_alu_out),
        .store_data_in(ex_mem_rt_fwd),
        .dest_in(ex_mem_dest),
        .valid_in(ex_mem_valid),
        .reg_write_in(ex_mem_reg_write),
        .mem_write_in(ex_mem_mem_write),
        .mem_read_in(ex_mem_mem_read),
        .mem_to_reg_in(ex_mem_mem_to_reg),
        .cache_req_valid(dcache_req_valid),
        .cache_req_ready(dcache_req_ready),
        .cache_req_write(dcache_req_write),
        .cache_req_addr(dcache_req_addr),
        .cache_req_wdata(dcache_req_wdata),
        .cache_resp_valid(dcache_resp_valid),
        .cache_resp_rdata(dcache_resp_rdata),
        .mem_stall(mem_stall),
        .wb_alu_out(mem_stage_alu_out),
        .wb_mem_data(mem_stage_mem_data),
        .wb_dest(mem_stage_dest),
        .wb_valid(mem_stage_valid),
        .wb_reg_write(mem_stage_reg_write),
        .wb_mem_to_reg(mem_stage_mem_to_reg)
    );

    mem_wb_reg u_mem_wb_reg (
        .clk(clk),
        .rst(rst),
        .alu_out_in(mem_stage_alu_out),
        .mem_data_in(mem_stage_mem_data),
        .dest_in(mem_stage_dest),
        .valid_in(mem_stage_valid),
        .reg_write_in(mem_stage_reg_write),
        .mem_to_reg_in(mem_stage_mem_to_reg),
        .alu_out_out(mem_wb_alu_out),
        .mem_data_out(mem_wb_mem_data),
        .dest_out(mem_wb_dest),
        .valid_out(mem_wb_valid),
        .reg_write_out(mem_wb_reg_write),
        .mem_to_reg_out(mem_wb_mem_to_reg)
    );
endmodule

