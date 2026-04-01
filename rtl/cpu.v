import cpu_defs::*;

module cpu (
    input wire clk,
    input wire rst
);
    wire [ADDR_W-1:0] imem_addr;
    wire [DATA_W-1:0] imem_data;
    wire [ADDR_W-1:0] dmem_addr;
    wire [DATA_W-1:0] dmem_wdata;
    wire [DATA_W-1:0] dmem_rdata;
    wire dmem_we;

    core_pipeline u_core_pipeline (
        .clk(clk),
        .rst(rst),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .dmem_we(dmem_we),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata)
    );

    instr_mem u_instr_mem (
        .addr(imem_addr),
        .rdata(imem_data)
    );

    data_mem u_data_mem (
        .clk(clk),
        .rst(rst),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .we(dmem_we),
        .rdata(dmem_rdata)
    );
endmodule

