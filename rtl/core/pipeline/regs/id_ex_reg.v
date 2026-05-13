import cpu_defs::*;

module id_ex_reg (
    input wire clk,
    input wire rst,
    input wire stall,
    input wire flush,
    input wire [ADDR_W-1:0] pc_in,
    input wire [DATA_W-1:0] rs_data_in,
    input wire [DATA_W-1:0] rt_data_in,
    input wire [DATA_W-1:0] imm_ext_in,
    input wire [REG_ADDR_W-1:0] rs_in,
    input wire [REG_ADDR_W-1:0] rt_in,
    input wire [REG_ADDR_W-1:0] rd_in,
    input wire [REG_ADDR_W-1:0] dest_in,
    input wire [ISA_JADDR_W-1:0] jaddr_in,
    input wire valid_in,
    input wire reg_write_in,
    input wire mem_write_in,
    input wire mem_read_in,
    input wire mem_to_reg_in,
    input wire alu_src_in,
    input wire branch_in,
    input wire jump_in,
    input wire is_mul_in,
    input wire vm_cmd_valid_in,
    input wire [VM_OP_W-1:0] vm_cmd_op_in,
    input wire [ALU_OP_W-1:0] alu_op_in,
    output reg [ADDR_W-1:0] pc_out,
    output reg [DATA_W-1:0] rs_data_out,
    output reg [DATA_W-1:0] rt_data_out,
    output reg [DATA_W-1:0] imm_ext_out,
    output reg [REG_ADDR_W-1:0] rs_out,
    output reg [REG_ADDR_W-1:0] rt_out,
    output reg [REG_ADDR_W-1:0] rd_out,
    output reg [REG_ADDR_W-1:0] dest_out,
    output reg [ISA_JADDR_W-1:0] jaddr_out,
    output reg valid_out,
    output reg reg_write_out,
    output reg mem_write_out,
    output reg mem_read_out,
    output reg mem_to_reg_out,
    output reg alu_src_out,
    output reg branch_out,
    output reg jump_out,
    output reg is_mul_out,
    output reg vm_cmd_valid_out,
    output reg [VM_OP_W-1:0] vm_cmd_op_out,
    output reg [ALU_OP_W-1:0] alu_op_out
);
    task automatic clear_outputs;
        begin
            pc_out <= 0;
            rs_data_out <= 0;
            rt_data_out <= 0;
            imm_ext_out <= 0;
            rs_out <= 0;
            rt_out <= 0;
            rd_out <= 0;
            dest_out <= 0;
            jaddr_out <= 0;
            valid_out <= 1'b0;
            reg_write_out <= 1'b0;
            mem_write_out <= 1'b0;
            mem_read_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
            alu_src_out <= 1'b0;
            branch_out <= 1'b0;
            jump_out <= 1'b0;
            is_mul_out <= 1'b0;
            vm_cmd_valid_out <= 1'b0;
            vm_cmd_op_out <= VM_OP_NONE;
            alu_op_out <= ALU_NOP;
        end
    endtask

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clear_outputs();
        end else if (flush) begin
            clear_outputs();
        end else if (!stall) begin
            pc_out <= pc_in;
            rs_data_out <= rs_data_in;
            rt_data_out <= rt_data_in;
            imm_ext_out <= imm_ext_in;
            rs_out <= rs_in;
            rt_out <= rt_in;
            rd_out <= rd_in;
            dest_out <= dest_in;
            jaddr_out <= jaddr_in;
            valid_out <= valid_in;
            reg_write_out <= reg_write_in;
            mem_write_out <= mem_write_in;
            mem_read_out <= mem_read_in;
            mem_to_reg_out <= mem_to_reg_in;
            alu_src_out <= alu_src_in;
            branch_out <= branch_in;
            jump_out <= jump_in;
            is_mul_out <= is_mul_in;
            vm_cmd_valid_out <= vm_cmd_valid_in;
            vm_cmd_op_out <= vm_cmd_op_in;
            alu_op_out <= alu_op_in;
        end
    end
endmodule

