import cpu_defs::*;

module regfile (
    input wire clk,
    input wire rst,
    input wire [REG_ADDR_W-1:0] raddr1,
    input wire [REG_ADDR_W-1:0] raddr2,
    output wire [DATA_W-1:0] rdata1,
    output wire [DATA_W-1:0] rdata2,
    input wire we,
    input wire [REG_ADDR_W-1:0] waddr,
    input wire [DATA_W-1:0] wdata
);
    reg [DATA_W-1:0] regs [0:REG_COUNT-1];
    integer i;
    
    // DEBUG
    wire [DATA_W-1:0] dbg_reg0 = regs[0];
    wire [DATA_W-1:0] dbg_reg1 = regs[1];
    wire [DATA_W-1:0] dbg_reg2 = regs[2];
    wire [DATA_W-1:0] dbg_reg3 = regs[3];
    wire [DATA_W-1:0] dbg_reg4 = regs[4];
    wire [DATA_W-1:0] dbg_reg5 = regs[5];
    wire [DATA_W-1:0] dbg_reg6 = regs[6];
    wire [DATA_W-1:0] dbg_reg7 = regs[7];

    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < REG_COUNT; i = i + 1) begin
                regs[i] <= 0;
            end
        end else if (we && (waddr != 0)) begin
            regs[waddr] <= wdata;
        end
    end
endmodule

