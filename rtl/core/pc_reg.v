import cpu_defs::*;

module pc_reg (
    input wire clk,
    input wire rst,
    input wire store,
    input wire [ADDR_W-1:0] pc_in,
    output reg [ADDR_W-1:0] pc_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 0;
        end else if (store) begin
            pc_out <= pc_in;
        end
    end
endmodule

