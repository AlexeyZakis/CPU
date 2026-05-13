import cpu_defs::*;

module mem_stage (
    input wire clk,
    input wire rst,
    input wire [DATA_W-1:0] alu_out_in,
    input wire [DATA_W-1:0] store_data_in,
    input wire [REG_ADDR_W-1:0] dest_in,
    input wire valid_in,
    input wire reg_write_in,
    input wire mem_write_in,
    input wire mem_read_in,
    input wire mem_to_reg_in,
    input wire vm_cmd_valid_in,
    input wire [VM_OP_W-1:0] vm_cmd_op_in,
    output wire cache_req_valid,
    input wire cache_req_ready,
    output wire cache_req_write,
    output wire [ADDR_W-1:0] cache_req_addr,
    output wire [DATA_W-1:0] cache_req_wdata,
    input wire cache_resp_valid,
    input wire [DATA_W-1:0] cache_resp_rdata,
    output wire vm_cmd_valid,
    input wire vm_cmd_ready,
    output wire [VM_OP_W-1:0] vm_cmd_op,
    output wire [ADDR_W-1:0] vm_cmd_arg0,
    output wire [ADDR_W-1:0] vm_cmd_arg1,
    input wire vm_cmd_resp_valid,
    output wire mem_stall,
    output wire [DATA_W-1:0] wb_alu_out,
    output wire [DATA_W-1:0] wb_mem_data,
    output wire [REG_ADDR_W-1:0] wb_dest,
    output wire wb_valid,
    output wire wb_reg_write,
    output wire wb_mem_to_reg
);
    reg req_inflight;
    wire is_cache_op;
    wire is_vm_cmd;
    wire cache_req_fire;
    wire vm_cmd_fire;
    wire op_resp_valid;

    assign is_cache_op = valid_in && (mem_write_in || mem_read_in);
    assign is_vm_cmd = valid_in && vm_cmd_valid_in;

    assign cache_req_valid = is_cache_op && !req_inflight;
    assign cache_req_write = mem_write_in;
    assign cache_req_addr = alu_out_in;
    assign cache_req_wdata = store_data_in;
    assign cache_req_fire = cache_req_valid && cache_req_ready;

    assign vm_cmd_valid = is_vm_cmd && !req_inflight;
    assign vm_cmd_op = vm_cmd_op_in;
    assign vm_cmd_arg0 = alu_out_in;
    assign vm_cmd_arg1 = store_data_in;
    assign vm_cmd_fire = vm_cmd_valid && vm_cmd_ready;

    assign op_resp_valid = is_cache_op ? cache_resp_valid : (is_vm_cmd ? vm_cmd_resp_valid : 1'b1);
    assign mem_stall = (is_cache_op || is_vm_cmd) && !op_resp_valid;

    assign wb_alu_out = alu_out_in;
    assign wb_mem_data = cache_resp_rdata;
    assign wb_dest = dest_in;
    assign wb_valid = valid_in && op_resp_valid;
    assign wb_reg_write = reg_write_in && !is_vm_cmd;
    assign wb_mem_to_reg = mem_to_reg_in;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            req_inflight <= 1'b0;
        end else if (!valid_in || (!is_cache_op && !is_vm_cmd)) begin
            req_inflight <= 1'b0;
        end else begin
            if (cache_req_fire || vm_cmd_fire) begin
                req_inflight <= 1'b1;
            end
            if (op_resp_valid) begin
                req_inflight <= 1'b0;
            end
        end
    end
endmodule
