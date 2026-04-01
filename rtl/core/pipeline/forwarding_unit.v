import cpu_defs::*;

module forwarding_unit (
    input wire [REG_ADDR_W-1:0] id_ex_rs,
    input wire [REG_ADDR_W-1:0] id_ex_rt,
    input wire ex_mem_reg_write,
    input wire [REG_ADDR_W-1:0] ex_mem_dest,
    input wire mem_wb_reg_write,
    input wire [REG_ADDR_W-1:0] mem_wb_dest,
    output reg [1:0] fwd_a_sel,
    output reg [1:0] fwd_b_sel
);
    wire fwd_a_from_ex = ex_mem_reg_write && (ex_mem_dest != 0) && (ex_mem_dest == id_ex_rs);
    wire fwd_a_from_wb = mem_wb_reg_write && (mem_wb_dest != 0) && (mem_wb_dest == id_ex_rs);

    wire fwd_b_from_ex = ex_mem_reg_write && (ex_mem_dest != 0) && (ex_mem_dest == id_ex_rt);
    wire fwd_b_from_wb = mem_wb_reg_write && (mem_wb_dest != 0) && (mem_wb_dest == id_ex_rt);

    always @(*) begin
        fwd_a_sel = FWD_SEL_REG;
        if (fwd_a_from_ex) begin
            fwd_a_sel = FWD_SEL_EX_MEM;
        end else if (fwd_a_from_wb) begin
            fwd_a_sel = FWD_SEL_WB;
        end

        fwd_b_sel = FWD_SEL_REG;
        if (fwd_b_from_ex) begin
            fwd_b_sel = FWD_SEL_EX_MEM;
        end else if (fwd_b_from_wb) begin
            fwd_b_sel = FWD_SEL_WB;
        end
    end
endmodule

