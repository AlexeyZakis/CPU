import cpu_defs::*;

module mul_unit_iterative (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [DATA_W-1:0] a,
    input wire [DATA_W-1:0] b,
    output reg busy,
    output reg done,
    output reg [DATA_W-1:0] result
);
    reg [DATA_W-1:0] multiplicand;
    reg [DATA_W-1:0] multiplier;
    reg [DATA_W-1:0] accum;
    reg [MUL_CNT_W-1:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            result <= 0;
            multiplicand <= 0;
            multiplier <= 0;
            accum <= 0;
            count <= 0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
                multiplicand <= a;
                multiplier <= b;
                accum <= 0;
                count <= DATA_W[MUL_CNT_W-1:0];
            end else if (busy) begin
                if (multiplier[0]) begin
                    accum <= accum + multiplicand;
                end
                multiplicand <= multiplicand << 1;
                multiplier <= multiplier >> 1;
                count <= count - 1'b1;
                if (count == 1) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    result <= multiplier[0] ? (accum + multiplicand) : accum;
                end
            end
        end
    end
endmodule

