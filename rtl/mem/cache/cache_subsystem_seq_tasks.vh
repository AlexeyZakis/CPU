task automatic reset_cache_state;
    integer bank_i;
    integer way_i;
    integer set_i;
    integer word_i;
    begin
        cpu_resp_valid <= 1'b0;
        cpu_resp_rdata <= 0;
        pipe_valid <= 1'b0;
        pipe_write <= 1'b0;
        pipe_addr <= 0;
        pipe_wdata <= 0;
        miss_active <= 1'b0;
        miss_write <= 1'b0;
        miss_bank <= 1'b0;
        miss_set <= 0;
        miss_way <= 1'b0;
        miss_addr <= 0;
        miss_wdata <= 0;
        miss_critical_word <= 0;
        miss_step <= 0;
        miss_from_l2 <= 1'b0;
        miss_resp_sent <= 1'b0;
        miss_l2_set <= 0;
        miss_l2_tag <= 0;
        miss_l1_tag <= 0;
        refill_wait_mem <= 1'b0;
        refill_word_cur <= 0;
        refill_word_data <= 0;
        wb_set_cur <= 0;
        wb_tag_cur <= 0;
        wb_word_cur <= 0;
        wb_push_valid <= 1'b0;
        wb_push_addr <= 0;
        wb_push_data <= 0;
        wb_pop_ready <= 1'b0;
        mem_req_valid <= 1'b0;
        mem_req_write <= 1'b0;
        mem_req_addr <= 0;
        mem_req_wdata <= 0;
        for (bank_i = 0; bank_i < L1_BANKS; bank_i = bank_i + 1) begin
            for (set_i = 0; set_i < L1_SETS_PER_BANK; set_i = set_i + 1) begin
                l1_lru[bank_i][set_i] <= 1'b0;
                for (way_i = 0; way_i < L1_WAYS; way_i = way_i + 1) begin
                    l1_valid[bank_i][way_i][set_i] <= 1'b0;
                    l1_tag[bank_i][way_i][set_i] <= 0;
                    for (word_i = 0; word_i < L1_LINE_WORDS; word_i = word_i + 1) begin
                        l1_data[bank_i][way_i][set_i][word_i] <= 0;
                    end
                end
            end
        end
        for (set_i = 0; set_i < L2_SETS; set_i = set_i + 1) begin
            l2_valid[set_i] <= 1'b0;
            l2_tag[set_i] <= 0;
            for (word_i = 0; word_i < L1_LINE_WORDS; word_i = word_i + 1) begin
                l2_data[set_i][word_i] <= 0;
            end
        end
        for (word_i = 0; word_i < L1_LINE_WORDS; word_i = word_i + 1) begin
            miss_line_buf[word_i] <= 0;
        end
    end
endtask

task automatic clear_cycle_outputs;
    begin
        cpu_resp_valid <= 1'b0;
        wb_push_valid <= 1'b0;
        wb_pop_ready <= 1'b0;
        mem_req_valid <= 1'b0;
        mem_req_write <= 1'b0;
        mem_req_addr <= 0;
        mem_req_wdata <= 0;
    end
endtask

task automatic accept_cpu_request;
    begin
        if (cpu_req_valid && cpu_req_ready) begin
            pipe_valid <= 1'b1;
            pipe_write <= cpu_req_write;
            pipe_addr <= cpu_req_addr;
            pipe_wdata <= cpu_req_wdata;
        end
    end
endtask

task automatic start_miss_tracking;
    begin
        miss_active <= 1'b1;
        miss_write <= pipe_write;
        miss_bank <= stage_bank;
        miss_set <= stage_set;
        miss_way <= stage_replace_way;
        miss_addr <= get_line_addr(pipe_addr);
        miss_wdata <= pipe_wdata;
        miss_critical_word <= stage_word;
        miss_step <= 0;
        miss_from_l2 <= stage_l2_hit;
        miss_resp_sent <= 1'b0;
        miss_l2_set <= stage_l2_set;
        miss_l2_tag <= stage_l2_tag;
        miss_l1_tag <= stage_tag;
        refill_wait_mem <= 1'b0;
        pipe_valid <= 1'b0;
    end
endtask

task automatic complete_pipe_hit;
    begin
        if (pipe_write) begin
            l1_data[stage_bank][stage_way][stage_set][stage_word] <= pipe_wdata;
            l1_lru[stage_bank][stage_set] <= ~stage_way;
            wb_push_valid <= 1'b1;
            wb_push_addr <= pipe_addr;
            wb_push_data <= pipe_wdata;
            cpu_resp_valid <= 1'b1;
            cpu_resp_rdata <= pipe_wdata;
        end else begin
            l1_lru[stage_bank][stage_set] <= ~stage_way;
            cpu_resp_valid <= 1'b1;
            cpu_resp_rdata <= stage_rdata;
        end
        pipe_valid <= 1'b0;
    end
endtask

task automatic process_pipe_stage;
    begin
        if (pipe_valid) begin
            if (stage_hit) begin
                complete_pipe_hit();
            end else if (!miss_active) begin
                start_miss_tracking();
            end
        end
    end
endtask

task automatic send_miss_response;
    input [DATA_W-1:0] response_data;
    begin
        if ((refill_word_idx(miss_critical_word, miss_step) == miss_critical_word) && !miss_resp_sent) begin
            cpu_resp_valid <= 1'b1;
            cpu_resp_rdata <= response_data;
            miss_resp_sent <= 1'b1;
            if (miss_write) begin
                wb_push_valid <= 1'b1;
                wb_push_addr <= get_word_addr(miss_addr, miss_critical_word);
                wb_push_data <= miss_wdata;
            end
        end
    end
endtask

task automatic finish_l1_fill;
    begin
        l1_valid[miss_bank][miss_way][miss_set] <= 1'b1;
        l1_tag[miss_bank][miss_way][miss_set] <= miss_l1_tag;
        l1_lru[miss_bank][miss_set] <= ~miss_way;
        miss_active <= 1'b0;
    end
endtask

task automatic process_l2_refill_step;
    reg [LINE_WORD_IDX_W-1:0] cur_word;
    reg [DATA_W-1:0] cur_data;
    begin
        cur_word = refill_word_idx(miss_critical_word, miss_step);
        cur_data = l2_data[miss_l2_set][cur_word];
        refill_word_cur <= cur_word;
        if (miss_write && (cur_word == miss_critical_word)) begin
            cur_data = miss_wdata;
            l2_data[miss_l2_set][cur_word] <= miss_wdata;
        end
        refill_word_data <= cur_data;
        l1_data[miss_bank][miss_way][miss_set][cur_word] <= cur_data;
        miss_line_buf[cur_word] <= cur_data;
        send_miss_response(cur_data);
        if (miss_step == L1_LINE_WORDS - 1) begin
            finish_l1_fill();
        end else begin
            miss_step <= miss_step + 1'b1;
        end
    end
endtask

task automatic process_mem_refill_step;
    integer word_i;
    reg [LINE_WORD_IDX_W-1:0] cur_word;
    reg [DATA_W-1:0] cur_data;
    begin
        cur_word = refill_word_idx(miss_critical_word, miss_step);
        refill_word_cur <= cur_word;
        if (!refill_wait_mem) begin
            mem_req_valid <= 1'b1;
            mem_req_write <= 1'b0;
            mem_req_addr <= get_word_addr(miss_addr, cur_word);
            refill_wait_mem <= 1'b1;
        end else if (mem_resp_valid) begin
            cur_data = mem_resp_rdata;
            if (miss_write && (cur_word == miss_critical_word)) begin
                cur_data = miss_wdata;
            end
            refill_word_data <= cur_data;
            l1_data[miss_bank][miss_way][miss_set][cur_word] <= cur_data;
            miss_line_buf[cur_word] <= cur_data;
            send_miss_response(cur_data);
            refill_wait_mem <= 1'b0;
            if (miss_step == L1_LINE_WORDS - 1) begin
                finish_l1_fill();
                l2_valid[miss_l2_set] <= 1'b1;
                l2_tag[miss_l2_set] <= miss_l2_tag;
                for (word_i = 0; word_i < L1_LINE_WORDS; word_i = word_i + 1) begin
                    l2_data[miss_l2_set][word_i] <= miss_line_buf[word_i];
                end
                l2_data[miss_l2_set][cur_word] <= cur_data;
            end else begin
                miss_step <= miss_step + 1'b1;
            end
        end
    end
endtask

task automatic process_miss_stage;
    begin
        if (miss_active) begin
            if (miss_from_l2) begin
                process_l2_refill_step();
            end else begin
                process_mem_refill_step();
            end
        end
    end
endtask

task automatic drain_write_buffer;
    begin
        if (!miss_active && wb_pop_valid) begin
            wb_set_cur <= get_l2_set(wb_pop_addr);
            wb_tag_cur <= get_l2_tag(wb_pop_addr);
            wb_word_cur <= get_word_idx(wb_pop_addr);
            if (l2_valid[get_l2_set(wb_pop_addr)] && (l2_tag[get_l2_set(wb_pop_addr)] == get_l2_tag(wb_pop_addr))) begin
                l2_data[get_l2_set(wb_pop_addr)][get_word_idx(wb_pop_addr)] <= wb_pop_data;
            end
            mem_req_valid <= 1'b1;
            mem_req_write <= 1'b1;
            mem_req_addr <= wb_pop_addr;
            mem_req_wdata <= wb_pop_data;
            wb_pop_ready <= 1'b1;
        end
    end
endtask

