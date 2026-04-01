import cpu_defs::*;

module ex_mem_reg (
    input wire clk,
    input wire rst,
    input wire [DATA_W-1:0] alu_out_in,
    input wire [DATA_W-1:0] rt_fwd_in,
    input wire [REG_ADDR_W-1:0] dest_in,
    input wire valid_in,
    input wire reg_write_in,
    input wire mem_write_in,
    input wire mem_read_in,
    input wire mem_to_reg_in,
    output reg [DATA_W-1:0] alu_out_out,
    output reg [DATA_W-1:0] rt_fwd_out,
    output reg [REG_ADDR_W-1:0] dest_out,
    output reg valid_out,
    output reg reg_write_out,
    output reg mem_write_out,
    output reg mem_read_out,
    output reg mem_to_reg_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_out_out <= 0;
            rt_fwd_out <= 0;
            dest_out <= 0;
            valid_out <= 1'b0;
            reg_write_out <= 1'b0;
            mem_write_out <= 1'b0;
            mem_read_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
        end else begin
            alu_out_out <= alu_out_in;
            rt_fwd_out <= rt_fwd_in;
            dest_out <= dest_in;
            valid_out <= valid_in;
            reg_write_out <= reg_write_in;
            mem_write_out <= mem_write_in;
            mem_read_out <= mem_read_in;
            mem_to_reg_out <= mem_to_reg_in;
        end
    end
endmodule

