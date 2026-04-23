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
    output wire cache_req_valid,
    input wire cache_req_ready,
    output wire cache_req_write,
    output wire [ADDR_W-1:0] cache_req_addr,
    output wire [DATA_W-1:0] cache_req_wdata,
    input wire cache_resp_valid,
    input wire [DATA_W-1:0] cache_resp_rdata,
    output wire mem_stall,
    output wire [DATA_W-1:0] wb_alu_out,
    output wire [DATA_W-1:0] wb_mem_data,
    output wire [REG_ADDR_W-1:0] wb_dest,
    output wire wb_valid,
    output wire wb_reg_write,
    output wire wb_mem_to_reg
);
    reg req_inflight;
    wire is_mem_op;
    wire req_fire;

    assign is_mem_op = valid_in && (mem_write_in || mem_read_in);
    assign cache_req_valid = is_mem_op && !req_inflight;
    assign cache_req_write = mem_write_in;
    assign cache_req_addr = alu_out_in;
    assign cache_req_wdata = store_data_in;
    assign req_fire = cache_req_valid && cache_req_ready;

    assign mem_stall = is_mem_op && !cache_resp_valid;

    assign wb_alu_out = alu_out_in;
    assign wb_mem_data = cache_resp_rdata;
    assign wb_dest = dest_in;
    assign wb_valid = valid_in && (!is_mem_op || cache_resp_valid);
    assign wb_reg_write = reg_write_in;
    assign wb_mem_to_reg = mem_to_reg_in;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            req_inflight <= 1'b0;
        end else if (!valid_in || !is_mem_op) begin
            req_inflight <= 1'b0;
        end else begin
            if (req_fire) begin
                req_inflight <= 1'b1;
            end
            if (cache_resp_valid) begin
                req_inflight <= 1'b0;
            end
        end
    end
endmodule

