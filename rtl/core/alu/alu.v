import cpu_defs::*;

module alu (
    input wire [DATA_W-1:0] in1,
    input wire [DATA_W-1:0] in2,
    input wire [ALU_OP_W-1:0] op,
    output reg [DATA_W-1:0] out,
    output wire zero
);
    always @(*) begin
        case (op)
            ALU_ADD: out = in1 + in2;
            ALU_SUB: out = in1 - in2;
            ALU_AND: out = in1 & in2;
            ALU_OR : out = in1 | in2;
            ALU_SLT: out = ($signed(in1) < $signed(in2)) ? 1 : 0;
            default : out = 0;
        endcase
    end

    assign zero = (out == 0);
endmodule

