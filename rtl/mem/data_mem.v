import cpu_defs::*;

module data_mem (
    input wire clk,
    input wire rst,
    input wire req_valid,
    input wire req_write,
    input wire [ADDR_W-1:0] addr,
    input wire [DATA_W-1:0] wdata,
    output wire req_ready,
    output reg resp_valid,
    output reg [DATA_W-1:0] rdata
);
    reg [DATA_W-1:0] mem [0:DMEM_DEPTH-1];
    wire [DMEM_ADDR_W-1:0] word_addr;
    integer i;
    
    // DEBUG
    wire [DATA_W-1:0] dbg_mem0 = mem[0];
    wire [DATA_W-1:0] dbg_mem1 = mem[1];
    wire [DATA_W-1:0] dbg_mem2 = mem[2];
    wire [DATA_W-1:0] dbg_mem3 = mem[3];
    wire [DATA_W-1:0] dbg_mem4 = mem[4];
    wire [DATA_W-1:0] dbg_mem5 = mem[5];
    wire [DATA_W-1:0] dbg_mem6 = mem[6];
    wire [DATA_W-1:0] dbg_mem7 = mem[7];

    assign req_ready = 1'b1;
    assign word_addr = addr[DMEM_ADDR_W + BYTE_OFFSET_W - 1 : BYTE_OFFSET_W];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            resp_valid <= 1'b0;
            rdata <= 0;
            for (i = 0; i < DMEM_DEPTH; i = i + 1) begin
                mem[i] <= 0;
            end
        end else begin
            resp_valid <= 1'b0;
            if (req_valid) begin
                if (req_write) begin
                    mem[word_addr] <= wdata;
                    rdata <= wdata;
                end else begin
                    rdata <= mem[word_addr];
                end
                resp_valid <= 1'b1;
            end
        end
    end
endmodule

