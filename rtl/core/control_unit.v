import cpu_defs::*;

module control_unit (
    input wire [ISA_OPC_W-1:0] opcode,
    input wire [ISA_FUNCT_W-1:0] funct,
    output reg reg_write,
    output reg mem_write,
    output reg mem_read,
    output reg mem_to_reg,
    output reg alu_src,
    output reg reg_dst,
    output reg branch,
    output reg jump,
    output reg is_mul,
    output reg [ALU_OP_W-1:0] alu_op
);
    always @(*) begin
        reg_write = 1'b0;
        mem_write = 1'b0;
        mem_read = 1'b0;
        mem_to_reg = 1'b0;
        alu_src = 1'b0;
        reg_dst = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        is_mul = 1'b0;
        alu_op = ALU_NOP;

        case (opcode)
            OPC_RTYPE: begin
                reg_write = 1'b1;
                reg_dst = 1'b1;
                case (funct)
                    FUNCT_ADD: alu_op = ALU_ADD;
                    FUNCT_SUB: alu_op = ALU_SUB;
                    FUNCT_AND: alu_op = ALU_AND;
                    FUNCT_OR: alu_op = ALU_OR;
                    FUNCT_SLT: alu_op = ALU_SLT;
                    FUNCT_MUL: begin
                        alu_op = ALU_MUL;
                        is_mul = 1'b1;
                    end
                    default: begin
                        reg_write = 1'b0;
                        alu_op = ALU_NOP;
                    end
                endcase
            end
            OPC_ADDI: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
            end
            OPC_LW: begin
                reg_write = 1'b1;
                mem_read = 1'b1;
                mem_to_reg = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
            end
            OPC_SW: begin
                mem_write = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
            end
            OPC_BEQ: begin
                branch = 1'b1;
                alu_op = ALU_SUB;
            end
            OPC_J: begin
                jump = 1'b1;
            end
            default: begin end
        endcase
    end
endmodule

