import cpu_defs::*;

module next_pc_mux (
    input wire [ADDR_W-1:0] pc_plus_byte_offset,
    input wire [ADDR_W-1:0] branch_target,
    input wire [ADDR_W-1:0] jump_target,
    input wire take_branch,
    input wire jump,
    output wire [ADDR_W-1:0] next_pc
);
    assign next_pc = jump
                        ? jump_target
                        : take_branch
                            ? branch_target
                            : pc_plus_byte_offset;
endmodule

