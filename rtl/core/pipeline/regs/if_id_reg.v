import cpu_defs::*;

module if_id_reg (
    input wire clk,
    input wire rst,
    input wire stall,
    input wire flush,
    input wire [ADDR_W-1:0] pc_in,
    input wire [INSTR_W-1:0] instr_in,
    input wire valid_in,
    output reg [ADDR_W-1:0] pc_out,
    output reg [INSTR_W-1:0] instr_out,
    output reg valid_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 0;
            instr_out <= 0;
            valid_out <= 1'b0;
        end else if (flush) begin
            pc_out <= 0;
            instr_out <= 0;
            valid_out <= 1'b0;
        end else if (!stall) begin
            pc_out <= pc_in;
            instr_out <= instr_in;
            valid_out <= valid_in;
        end
    end
endmodule

