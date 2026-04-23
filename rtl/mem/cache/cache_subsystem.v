import cpu_defs::*;

module cache_subsystem (
    input wire clk,
    input wire rst,
    input wire cpu_req_valid,
    output wire cpu_req_ready,
    input wire cpu_req_write,
    input wire [ADDR_W-1:0] cpu_req_addr,
    input wire [DATA_W-1:0] cpu_req_wdata,
    output reg cpu_resp_valid,
    output reg [DATA_W-1:0] cpu_resp_rdata
);
    localparam L1_TAG_W = ADDR_W - BYTE_OFFSET_W - LINE_WORD_IDX_W - L1_TOTAL_SET_W;
    localparam L2_TAG_W = ADDR_W - BYTE_OFFSET_W - LINE_WORD_IDX_W - L2_SET_W;

    reg [DATA_W-1:0] l1_data [0:L1_BANKS-1][0:L1_WAYS-1][0:L1_SETS_PER_BANK-1][0:L1_LINE_WORDS-1];
    reg [L1_TAG_W-1:0] l1_tag [0:L1_BANKS-1][0:L1_WAYS-1][0:L1_SETS_PER_BANK-1];
    reg l1_valid [0:L1_BANKS-1][0:L1_WAYS-1][0:L1_SETS_PER_BANK-1];
    reg l1_lru [0:L1_BANKS-1][0:L1_SETS_PER_BANK-1];

    reg [DATA_W-1:0] l2_data [0:L2_SETS-1][0:L1_LINE_WORDS-1];
    reg [L2_TAG_W-1:0] l2_tag [0:L2_SETS-1];
    reg l2_valid [0:L2_SETS-1];

    reg pipe_valid;
    reg pipe_write;
    reg [ADDR_W-1:0] pipe_addr;
    reg [DATA_W-1:0] pipe_wdata;

    reg miss_active;
    reg miss_write;
    reg miss_bank;
    reg [L1_SET_W-1:0] miss_set;
    reg miss_way;
    reg [ADDR_W-1:0] miss_addr;
    reg [DATA_W-1:0] miss_wdata;
    reg [LINE_WORD_IDX_W-1:0] miss_critical_word;
    reg [1:0] miss_step;
    reg miss_from_l2;
    reg miss_resp_sent;
    reg [L2_SET_W-1:0] miss_l2_set;
    reg [L2_TAG_W-1:0] miss_l2_tag;
    reg [L1_TAG_W-1:0] miss_l1_tag;
    reg [DATA_W-1:0] miss_line_buf [0:L1_LINE_WORDS-1];
    reg refill_wait_mem;

    reg [LINE_WORD_IDX_W-1:0] refill_word_cur;
    reg [DATA_W-1:0] refill_word_data;
    reg [L2_SET_W-1:0] wb_set_cur;
    reg [L2_TAG_W-1:0] wb_tag_cur;
    reg [LINE_WORD_IDX_W-1:0] wb_word_cur;

    wire wb_full;
    wire wb_pop_valid;
    wire [ADDR_W-1:0] wb_pop_addr;
    wire [DATA_W-1:0] wb_pop_data;
    reg wb_push_valid;
    reg [ADDR_W-1:0] wb_push_addr;
    reg [DATA_W-1:0] wb_push_data;
    reg wb_pop_ready;

    reg mem_req_valid;
    reg mem_req_write;
    reg [ADDR_W-1:0] mem_req_addr;
    reg [DATA_W-1:0] mem_req_wdata;
    wire mem_req_ready;
    wire mem_resp_valid;
    wire [DATA_W-1:0] mem_resp_rdata;

    integer stage_lookup_i;
    integer incoming_lookup_i;

    wire cpu_bank_busy;
    wire incoming_hit;

    reg stage_hit;
    reg stage_way;
    reg [DATA_W-1:0] stage_rdata;
    reg stage_replace_way;
    reg stage_bank;
    reg [L1_SET_W-1:0] stage_set;
    reg [LINE_WORD_IDX_W-1:0] stage_word;
    reg [L1_TAG_W-1:0] stage_tag;
    reg [L2_SET_W-1:0] stage_l2_set;
    reg [L2_TAG_W-1:0] stage_l2_tag;
    reg stage_l2_hit;

    reg incoming_hit_r;
    reg incoming_bank_r;
    reg [L1_SET_W-1:0] incoming_set_r;
    reg [L1_TAG_W-1:0] incoming_tag_r;

    function automatic [L1_BANK_W-1:0] get_bank;
        input [ADDR_W-1:0] addr;
        reg [L1_TOTAL_SET_W-1:0] total_set;
        begin
            total_set = addr[BYTE_OFFSET_W + LINE_WORD_IDX_W + L1_TOTAL_SET_W - 1 : BYTE_OFFSET_W + LINE_WORD_IDX_W];
            get_bank = total_set[0];
        end
    endfunction

    function automatic [L1_SET_W-1:0] get_bank_set;
        input [ADDR_W-1:0] addr;
        reg [L1_TOTAL_SET_W-1:0] total_set;
        begin
            total_set = addr[BYTE_OFFSET_W + LINE_WORD_IDX_W + L1_TOTAL_SET_W - 1 : BYTE_OFFSET_W + LINE_WORD_IDX_W];
            get_bank_set = total_set[L1_TOTAL_SET_W - 1 : 1];
        end
    endfunction

    function automatic [LINE_WORD_IDX_W-1:0] get_word_idx;
        input [ADDR_W-1:0] addr;
        begin
            get_word_idx = addr[BYTE_OFFSET_W + LINE_WORD_IDX_W - 1 : BYTE_OFFSET_W];
        end
    endfunction

    function automatic [L1_TAG_W-1:0] get_l1_tag;
        input [ADDR_W-1:0] addr;
        begin
            get_l1_tag = addr[ADDR_W - 1 : BYTE_OFFSET_W + LINE_WORD_IDX_W + L1_TOTAL_SET_W];
        end
    endfunction

    function automatic [L2_SET_W-1:0] get_l2_set;
        input [ADDR_W-1:0] addr;
        begin
            get_l2_set = addr[BYTE_OFFSET_W + LINE_WORD_IDX_W + L2_SET_W - 1 : BYTE_OFFSET_W + LINE_WORD_IDX_W];
        end
    endfunction

    function automatic [L2_TAG_W-1:0] get_l2_tag;
        input [ADDR_W-1:0] addr;
        begin
            get_l2_tag = addr[ADDR_W - 1 : BYTE_OFFSET_W + LINE_WORD_IDX_W + L2_SET_W];
        end
    endfunction

    function automatic [ADDR_W-1:0] get_line_addr;
        input [ADDR_W-1:0] addr;
        begin
            get_line_addr = {addr[ADDR_W - 1 : BYTE_OFFSET_W + LINE_WORD_IDX_W], {BYTE_OFFSET_W + LINE_WORD_IDX_W{1'b0}}};
        end
    endfunction

    function automatic [ADDR_W-1:0] get_word_addr;
        input [ADDR_W-1:0] line_addr;
        input [LINE_WORD_IDX_W-1:0] word_idx;
        begin
            get_word_addr = line_addr | (word_idx << BYTE_OFFSET_W);
        end
    endfunction

    function automatic [LINE_WORD_IDX_W-1:0] refill_word_idx;
        input [LINE_WORD_IDX_W-1:0] critical;
        input [1:0] step;
        begin
            refill_word_idx = (critical + step) & (L1_LINE_WORDS - 1);
        end
    endfunction

    always @(*) begin
        stage_hit = 1'b0;
        stage_way = 1'b0;
        stage_rdata = 0;
        stage_bank = get_bank(pipe_addr);
        stage_set = get_bank_set(pipe_addr);
        stage_word = get_word_idx(pipe_addr);
        stage_tag = get_l1_tag(pipe_addr);
        stage_l2_set = get_l2_set(pipe_addr);
        stage_l2_tag = get_l2_tag(pipe_addr);
        stage_l2_hit = l2_valid[stage_l2_set] && (l2_tag[stage_l2_set] == stage_l2_tag);
        stage_replace_way = l1_lru[stage_bank][stage_set];
        if (!l1_valid[stage_bank][0][stage_set]) begin
            stage_replace_way = 1'b0;
        end else if (!l1_valid[stage_bank][1][stage_set]) begin
            stage_replace_way = 1'b1;
        end
        for (stage_lookup_i = 0; stage_lookup_i < L1_WAYS; stage_lookup_i = stage_lookup_i + 1) begin
            if (l1_valid[stage_bank][stage_lookup_i][stage_set] && (l1_tag[stage_bank][stage_lookup_i][stage_set] == stage_tag)) begin
                stage_hit = 1'b1;
                stage_way = stage_lookup_i[0];
                stage_rdata = l1_data[stage_bank][stage_lookup_i][stage_set][stage_word];
            end
        end
    end

    always @(*) begin
        incoming_hit_r = 1'b0;
        incoming_bank_r = get_bank(cpu_req_addr);
        incoming_set_r = get_bank_set(cpu_req_addr);
        incoming_tag_r = get_l1_tag(cpu_req_addr);
        for (incoming_lookup_i = 0; incoming_lookup_i < L1_WAYS; incoming_lookup_i = incoming_lookup_i + 1) begin
            if (l1_valid[incoming_bank_r][incoming_lookup_i][incoming_set_r] && (l1_tag[incoming_bank_r][incoming_lookup_i][incoming_set_r] == incoming_tag_r)) begin
                incoming_hit_r = 1'b1;
            end
        end
    end

    assign cpu_bank_busy = miss_active && (get_bank(cpu_req_addr) == miss_bank);
    assign incoming_hit = incoming_hit_r;
    assign cpu_req_ready = !pipe_valid && (!cpu_req_write || !wb_full) && (!miss_active || (!cpu_bank_busy && incoming_hit));

    write_buffer u_write_buffer (
        .clk(clk),
        .rst(rst),
        .push_valid(wb_push_valid),
        .push_addr(wb_push_addr),
        .push_data(wb_push_data),
        .full(wb_full),
        .empty(),
        .pop_valid(wb_pop_valid),
        .pop_addr(wb_pop_addr),
        .pop_data(wb_pop_data),
        .pop_ready(wb_pop_ready)
    );

    data_mem u_main_mem (
        .clk(clk),
        .rst(rst),
        .req_valid(mem_req_valid),
        .req_write(mem_req_write),
        .addr(mem_req_addr),
        .wdata(mem_req_wdata),
        .req_ready(mem_req_ready),
        .resp_valid(mem_resp_valid),
        .rdata(mem_resp_rdata)
    );
    
    `include "cache_subsystem_seq_tasks.vh"
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reset_cache_state();
        end else begin
            clear_cycle_outputs();
            accept_cpu_request();
            process_pipe_stage();
            process_miss_stage();
            drain_write_buffer();
        end
    end
endmodule

