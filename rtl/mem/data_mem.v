import cpu_defs::*;

module data_mem (
    input wire clk,
    input wire rst,
    input wire [ADDR_W-1:0] addr,
    input wire [DATA_W-1:0] id,
    input wire w,
    output wire [DATA_W-1:0] od
);
    reg [DATA_W-1:0] mem [0:DMEM_DEPTH-1];
    wire [DMEM_ADDR_W-1:0] word_addr;
    
    // DEBUG
    wire [DATA_W-1:0] dbg_mem0 = mem[0];
    wire [DATA_W-1:0] dbg_mem1 = mem[1];
    wire [DATA_W-1:0] dbg_mem2 = mem[2];
    wire [DATA_W-1:0] dbg_mem3 = mem[3];
    wire [DATA_W-1:0] dbg_mem4 = mem[4];
    wire [DATA_W-1:0] dbg_mem5 = mem[5];
    wire [DATA_W-1:0] dbg_mem6 = mem[6];
    wire [DATA_W-1:0] dbg_mem7 = mem[7];
    
    integer i;

    assign word_addr = addr[DMEM_ADDR_W + BYTE_OFFSET_W - 1 : BYTE_OFFSET_W];
    assign od = mem[word_addr];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < DMEM_DEPTH; i = i + 1) begin
                mem[i] <= 0;
            end
        end else if (w) begin
            mem[word_addr] <= id;
        end
    end
endmodule

