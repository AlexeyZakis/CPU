import cpu_defs::*;

module cpu (
    input wire clk,
    input wire rst
);
    wire [ADDR_W-1:0] imem_addr;
    wire [DATA_W-1:0] imem_data;
    wire dcache_req_valid;
    wire dcache_req_ready;
    wire dcache_req_write;
    wire [ADDR_W-1:0] dcache_req_addr;
    wire [DATA_W-1:0] dcache_req_wdata;
    wire dcache_resp_valid;
    wire [DATA_W-1:0] dcache_resp_rdata;

    wire vm_cmd_valid;
    wire vm_cmd_ready;
    wire [VM_OP_W-1:0] vm_cmd_op;
    wire [ADDR_W-1:0] vm_cmd_arg0;
    wire [ADDR_W-1:0] vm_cmd_arg1;
    wire vm_cmd_resp_valid;

    core_pipeline u_core_pipeline (
        .clk(clk),
        .rst(rst),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .dcache_req_valid(dcache_req_valid),
        .dcache_req_ready(dcache_req_ready),
        .dcache_req_write(dcache_req_write),
        .dcache_req_addr(dcache_req_addr),
        .dcache_req_wdata(dcache_req_wdata),
        .dcache_resp_valid(dcache_resp_valid),
        .dcache_resp_rdata(dcache_resp_rdata),
        .vm_cmd_valid(vm_cmd_valid),
        .vm_cmd_ready(vm_cmd_ready),
        .vm_cmd_op(vm_cmd_op),
        .vm_cmd_arg0(vm_cmd_arg0),
        .vm_cmd_arg1(vm_cmd_arg1),
        .vm_cmd_resp_valid(vm_cmd_resp_valid)
    );

    instr_mem u_instr_mem (
        .addr(imem_addr),
        .rdata(imem_data)
    );

    cache_subsystem u_dcache (
        .clk(clk),
        .rst(rst),
        .cpu_req_valid(dcache_req_valid),
        .cpu_req_ready(dcache_req_ready),
        .cpu_req_write(dcache_req_write),
        .cpu_req_addr(dcache_req_addr),
        .cpu_req_wdata(dcache_req_wdata),
        .cpu_resp_valid(dcache_resp_valid),
        .cpu_resp_rdata(dcache_resp_rdata),
        .vm_cmd_valid(vm_cmd_valid),
        .vm_cmd_ready(vm_cmd_ready),
        .vm_cmd_op(vm_cmd_op),
        .vm_cmd_arg0(vm_cmd_arg0),
        .vm_cmd_arg1(vm_cmd_arg1),
        .vm_cmd_resp_valid(vm_cmd_resp_valid)
    );
endmodule
