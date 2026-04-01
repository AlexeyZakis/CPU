import cpu_defs::*;

module ex_stage (
    input wire clk,
    input wire rst,
    input wire [ADDR_W-1:0] pc_in,
    input wire [DATA_W-1:0] rs_data_in,
    input wire [DATA_W-1:0] rt_data_in,
    input wire [DATA_W-1:0] imm_ext_in,
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
    input wire [ALU_OP_W-1:0] alu_op_in,
    input wire [1:0] fwd_a_sel,
    input wire [1:0] fwd_b_sel,
    input wire [DATA_W-1:0] ex_mem_alu_out,
    input wire [DATA_W-1:0] wb_data,
    output wire busy_out,
    output wire redirect_out,
    output wire [ADDR_W-1:0] redirect_target_out,
    output wire [DATA_W-1:0] rt_fwd_out,
    output wire [DATA_W-1:0] alu_out_out,
    output wire [REG_ADDR_W-1:0] dest_out,
    output wire valid_out,
    output wire reg_write_out,
    output wire mem_write_out,
    output wire mem_read_out,
    output wire mem_to_reg_out,
    output wire [ADDR_W-1:0] pc_target_out
);
    reg [DATA_W-1:0] src_a;
    reg [DATA_W-1:0] src_b_pre;

    reg mul_start;
    reg [1:0] mul_state;

    reg [DATA_W-1:0] mul_a_reg;
    reg [DATA_W-1:0] mul_b_reg;
    reg [DATA_W-1:0] mul_result_reg;
    reg [REG_ADDR_W-1:0] mul_dest_reg;
    reg mul_valid_reg;
    reg mul_reg_write_reg;

    wire [DATA_W-1:0] alu_in2;
    wire [DATA_W-1:0] alu_out;
    wire alu_zero;
    wire [ADDR_W-1:0] pc_plus;
    wire [ADDR_W-1:0] branch_target;
    wire [ADDR_W-1:0] jump_target;
    wire take_branch;

    wire mul_busy;
    wire mul_done;
    wire [DATA_W-1:0] mul_result;

    wire mul_running;
    wire mul_commit;

    always @(*) begin
        case (fwd_a_sel)
            FWD_SEL_EX_MEM: src_a = ex_mem_alu_out;
            FWD_SEL_WB: src_a = wb_data;
            default: src_a = rs_data_in;
        endcase

        case (fwd_b_sel)
            FWD_SEL_EX_MEM: src_b_pre = ex_mem_alu_out;
            FWD_SEL_WB: src_b_pre = wb_data;
            default: src_b_pre = rt_data_in;
        endcase
    end

    assign alu_in2 = alu_src_in ? imm_ext_in : src_b_pre;
    assign pc_plus = pc_in + WORD_BYTES;
    assign branch_target = pc_plus + (imm_ext_in << BYTE_OFFSET_W);
    assign jump_target = {{(ADDR_W - ISA_JADDR_W - BYTE_OFFSET_W){1'b0}}, jaddr_in, {BYTE_OFFSET_W{1'b0}}};

    assign take_branch = branch_in && alu_zero;
    assign redirect_out = valid_in && (jump_in || take_branch);
    assign redirect_target_out = jump_in ? jump_target : branch_target;

    assign rt_fwd_out = src_b_pre;
    assign pc_target_out = redirect_target_out;

    assign mul_running = (mul_state == MUL_STATE_RUN);
    assign mul_commit = (mul_state == MUL_STATE_COMMIT);

    alu u_alu (
        .in1(src_a),
        .in2(alu_in2),
        .op(alu_op_in),
        .out(alu_out),
        .zero(alu_zero)
    );

    mul_unit_iterative u_mul (
        .clk(clk),
        .rst(rst),
        .start(mul_start),
        .a(mul_a_reg),
        .b(mul_b_reg),
        .busy(mul_busy),
        .done(mul_done),
        .result(mul_result)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mul_start <= 1'b0;
            mul_state <= MUL_STATE_IDLE;
            mul_a_reg <= 0;
            mul_b_reg <= 0;
            mul_result_reg <= 0;
            mul_dest_reg <= 0;
            mul_valid_reg <= 1'b0;
            mul_reg_write_reg <= 1'b0;
        end else begin
            mul_start <= 1'b0;

            case (mul_state)
                MUL_STATE_IDLE: begin
                    if (valid_in && is_mul_in && !mul_busy) begin
                        mul_a_reg <= src_a;
                        mul_b_reg <= src_b_pre;
                        mul_dest_reg <= dest_in;
                        mul_valid_reg <= valid_in;
                        mul_reg_write_reg <= reg_write_in;
                        mul_start <= 1'b1;
                        mul_state <= MUL_STATE_RUN;
                    end
                end

                MUL_STATE_RUN: begin
                    if (mul_done) begin
                        mul_result_reg <= mul_result;
                        mul_state <= MUL_STATE_COMMIT;
                    end
                end

                MUL_STATE_COMMIT: begin
                    mul_state <= MUL_STATE_IDLE;
                end

                default: begin
                    mul_state <= MUL_STATE_IDLE;
                end
            endcase
        end
    end

    assign busy_out = mul_running || mul_done || mul_commit;

    assign valid_out = mul_commit ? mul_valid_reg : valid_in;
    assign alu_out_out = mul_commit ? mul_result_reg : alu_out;
    assign dest_out = mul_commit ? mul_dest_reg : dest_in;
    assign reg_write_out = mul_commit ? mul_reg_write_reg : reg_write_in;

    assign mem_write_out = mul_commit ? 1'b0 : mem_write_in;
    assign mem_read_out = mul_commit ? 1'b0 : mem_read_in;
    assign mem_to_reg_out = mul_commit ? 1'b0 : mem_to_reg_in;
endmodule
