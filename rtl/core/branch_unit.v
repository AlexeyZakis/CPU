import cpu_defs::*;

module branch_unit (
    input wire [ADDR_W-1:0] pc_plus_byte_offset,
    input wire [DATA_W-1:0] imm_ext,
    input wire branch,
    input wire zero,
    output wire take_branch,
    output wire [ADDR_W-1:0] branch_target
);
    assign take_branch = branch & zero;
    assign branch_target = pc_plus_byte_offset + (imm_ext << BYTE_OFFSET_W);
endmodule

