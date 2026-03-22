import cpu_defs::*;

module imm_ext (
    input  wire [IMM_W-1:0] imm_in,
    output wire [DATA_W-1:0] imm_out
);
    assign imm_out = {{(DATA_W - IMM_W){imm_in[IMM_W-1]}}, imm_in};
endmodule

