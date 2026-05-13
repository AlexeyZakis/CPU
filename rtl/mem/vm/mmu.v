import cpu_defs::*;

module mmu (
    input wire clk,
    input wire rst,
    input wire translate_valid,
    input wire [ADDR_W-1:0] translate_vaddr,
    output wire translate_ok,
    output wire translate_fault,
    output wire translate_tlb_hit,
    output wire translate_page_hit,
    output wire [ADDR_W-1:0] translate_paddr,
    input wire cmd_valid,
    output wire cmd_ready,
    input wire [VM_OP_W-1:0] cmd_op,
    input wire [ADDR_W-1:0] cmd_arg0,
    input wire [ADDR_W-1:0] cmd_arg1,
    output wire cmd_resp_valid
);
    reg [ADDR_W-1:0] segment_base;
    reg [ADDR_W-1:0] segment_limit;

    reg l1_valid [0:VM_L1_ENTRIES-1];
    reg pte_valid [0:VM_L1_ENTRIES-1][0:VM_L2_ENTRIES-1];
    reg [PAGE_SIZE_W-1:0] pte_size [0:VM_L1_ENTRIES-1][0:VM_L2_ENTRIES-1];
    reg [ADDR_W-1:0] pte_vbase [0:VM_L1_ENTRIES-1][0:VM_L2_ENTRIES-1];
    reg [ADDR_W-1:0] pte_pbase [0:VM_L1_ENTRIES-1][0:VM_L2_ENTRIES-1];

    wire [ADDR_W-1:0] linear_addr;
    wire segment_ok;
    wire tlb_hit;
    wire [ADDR_W-1:0] tlb_paddr;
    wire [PAGE_SIZE_W-1:0] tlb_page_size;

    reg walk_hit;
    reg [ADDR_W-1:0] walk_paddr;
    reg [ADDR_W-1:0] walk_vbase;
    reg [ADDR_W-1:0] walk_pbase;
    reg [PAGE_SIZE_W-1:0] walk_page_size;

    wire fill_tlb;
    wire invalidate_tlb;

    integer l1_i;
    integer l2_i;
    integer reset_l1_i;
    integer reset_l2_i;

    function automatic [ADDR_W-1:0] align_page_base;
        input [ADDR_W-1:0] addr;
        input [PAGE_SIZE_W-1:0] size;
        begin
            if (size == PAGE_LARGE) begin
                align_page_base = {addr[ADDR_W-1:LARGE_PAGE_OFFSET_W], {LARGE_PAGE_OFFSET_W{1'b0}}};
            end else begin
                align_page_base = {addr[ADDR_W-1:SMALL_PAGE_OFFSET_W], {SMALL_PAGE_OFFSET_W{1'b0}}};
            end
        end
    endfunction

    function automatic page_match;
        input [ADDR_W-1:0] addr;
        input [ADDR_W-1:0] base;
        input [PAGE_SIZE_W-1:0] size;
        begin
            if (size == PAGE_LARGE) begin
                page_match = addr[ADDR_W-1:LARGE_PAGE_OFFSET_W] == base[ADDR_W-1:LARGE_PAGE_OFFSET_W];
            end else begin
                page_match = addr[ADDR_W-1:SMALL_PAGE_OFFSET_W] == base[ADDR_W-1:SMALL_PAGE_OFFSET_W];
            end
        end
    endfunction

    function automatic [ADDR_W-1:0] apply_page_offset;
        input [ADDR_W-1:0] addr;
        input [ADDR_W-1:0] base;
        input [PAGE_SIZE_W-1:0] size;
        begin
            if (size == PAGE_LARGE) begin
                apply_page_offset = {base[ADDR_W-1:LARGE_PAGE_OFFSET_W], addr[LARGE_PAGE_OFFSET_W-1:0]};
            end else begin
                apply_page_offset = {base[ADDR_W-1:SMALL_PAGE_OFFSET_W], addr[SMALL_PAGE_OFFSET_W-1:0]};
            end
        end
    endfunction

    function automatic [VM_L1_IDX_W-1:0] get_l1_idx;
        input [ADDR_W-1:0] addr;
        begin
            get_l1_idx = addr[SMALL_PAGE_OFFSET_W + VM_L2_IDX_W + VM_L1_IDX_W - 1 : SMALL_PAGE_OFFSET_W + VM_L2_IDX_W];
        end
    endfunction

    function automatic [VM_L2_IDX_W-1:0] get_l2_idx;
        input [ADDR_W-1:0] addr;
        begin
            get_l2_idx = addr[SMALL_PAGE_OFFSET_W + VM_L2_IDX_W - 1 : SMALL_PAGE_OFFSET_W];
        end
    endfunction

    assign linear_addr = segment_base + translate_vaddr;
    assign segment_ok = translate_vaddr < segment_limit;
    assign fill_tlb = translate_valid && segment_ok && !tlb_hit && walk_hit;
    assign translate_ok = translate_valid && segment_ok && (tlb_hit || walk_hit);
    assign translate_fault = translate_valid && !translate_ok;
    assign translate_tlb_hit = tlb_hit;
    assign translate_page_hit = walk_hit;
    assign translate_paddr = tlb_hit ? tlb_paddr : walk_paddr;
    assign cmd_ready = 1'b1;
    assign cmd_resp_valid = cmd_valid;
    assign invalidate_tlb = cmd_valid && ((cmd_op == VM_OP_TLB_INV) || (cmd_op == VM_OP_SET_SEG_BASE) || (cmd_op == VM_OP_SET_SEG_LIMIT) || (cmd_op == VM_OP_MAP_SMALL) || (cmd_op == VM_OP_MAP_LARGE));

    tlb u_tlb (
        .clk(clk),
        .rst(rst),
        .lookup_valid(translate_valid && segment_ok),
        .lookup_vaddr(linear_addr),
        .hit(tlb_hit),
        .paddr(tlb_paddr),
        .page_size(tlb_page_size),
        .fill_valid(fill_tlb),
        .fill_vbase(walk_vbase),
        .fill_pbase(walk_pbase),
        .fill_page_size(walk_page_size),
        .invalidate(invalidate_tlb)
    );

    always @(*) begin
        walk_hit = 1'b0;
        walk_paddr = 0;
        walk_vbase = 0;
        walk_pbase = 0;
        walk_page_size = PAGE_SMALL;
        for (l1_i = 0; l1_i < VM_L1_ENTRIES; l1_i = l1_i + 1) begin
            if (l1_valid[l1_i]) begin
                for (l2_i = 0; l2_i < VM_L2_ENTRIES; l2_i = l2_i + 1) begin
                    if (pte_valid[l1_i][l2_i] && page_match(linear_addr, pte_vbase[l1_i][l2_i], pte_size[l1_i][l2_i])) begin
                        walk_hit = 1'b1;
                        walk_paddr = apply_page_offset(linear_addr, pte_pbase[l1_i][l2_i], pte_size[l1_i][l2_i]);
                        walk_vbase = pte_vbase[l1_i][l2_i];
                        walk_pbase = pte_pbase[l1_i][l2_i];
                        walk_page_size = pte_size[l1_i][l2_i];
                    end
                end
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            segment_base <= 0;
            segment_limit <= DMEM_DEPTH * WORD_BYTES;
            for (reset_l1_i = 0; reset_l1_i < VM_L1_ENTRIES; reset_l1_i = reset_l1_i + 1) begin
                l1_valid[reset_l1_i] <= 1'b0;
                for (reset_l2_i = 0; reset_l2_i < VM_L2_ENTRIES; reset_l2_i = reset_l2_i + 1) begin
                    pte_valid[reset_l1_i][reset_l2_i] <= 1'b0;
                    pte_size[reset_l1_i][reset_l2_i] <= PAGE_SMALL;
                    pte_vbase[reset_l1_i][reset_l2_i] <= 0;
                    pte_pbase[reset_l1_i][reset_l2_i] <= 0;
                end
            end
        end else if (cmd_valid) begin
            case (cmd_op)
                VM_OP_SET_SEG_BASE: begin
                    segment_base <= cmd_arg0;
                end
                VM_OP_SET_SEG_LIMIT: begin
                    segment_limit <= cmd_arg0;
                end
                VM_OP_MAP_SMALL: begin
                    l1_valid[get_l1_idx(segment_base + cmd_arg0)] <= 1'b1;
                    pte_valid[get_l1_idx(segment_base + cmd_arg0)][get_l2_idx(segment_base + cmd_arg0)] <= 1'b1;
                    pte_size[get_l1_idx(segment_base + cmd_arg0)][get_l2_idx(segment_base + cmd_arg0)] <= PAGE_SMALL;
                    pte_vbase[get_l1_idx(segment_base + cmd_arg0)][get_l2_idx(segment_base + cmd_arg0)] <= align_page_base(segment_base + cmd_arg0, PAGE_SMALL);
                    pte_pbase[get_l1_idx(segment_base + cmd_arg0)][get_l2_idx(segment_base + cmd_arg0)] <= align_page_base(cmd_arg1, PAGE_SMALL);
                end
                VM_OP_MAP_LARGE: begin
                    l1_valid[get_l1_idx(segment_base + cmd_arg0)] <= 1'b1;
                    pte_valid[get_l1_idx(segment_base + cmd_arg0)][get_l2_idx(segment_base + cmd_arg0)] <= 1'b1;
                    pte_size[get_l1_idx(segment_base + cmd_arg0)][get_l2_idx(segment_base + cmd_arg0)] <= PAGE_LARGE;
                    pte_vbase[get_l1_idx(segment_base + cmd_arg0)][get_l2_idx(segment_base + cmd_arg0)] <= align_page_base(segment_base + cmd_arg0, PAGE_LARGE);
                    pte_pbase[get_l1_idx(segment_base + cmd_arg0)][get_l2_idx(segment_base + cmd_arg0)] <= align_page_base(cmd_arg1, PAGE_LARGE);
                end
                default: begin
                end
            endcase
        end
    end

    // Debug wires for GTKWave. Some simulators do not expose unpacked
    // arrays as ordinary signals, so the important page table entries are
    // mirrored as simple scalar/vector wires.
    wire dbg_l1_valid_0 = l1_valid[0];
    wire dbg_l1_valid_1 = l1_valid[1];
    wire dbg_l1_valid_2 = l1_valid[2];
    wire dbg_l1_valid_3 = l1_valid[3];

    wire dbg_pte_0_0_valid = pte_valid[0][0];
    wire dbg_pte_0_0_size = pte_size[0][0];
    wire [ADDR_W-1:0] dbg_pte_0_0_vbase = pte_vbase[0][0];
    wire [ADDR_W-1:0] dbg_pte_0_0_pbase = pte_pbase[0][0];

    wire dbg_pte_0_1_valid = pte_valid[0][1];
    wire dbg_pte_0_1_size = pte_size[0][1];
    wire [ADDR_W-1:0] dbg_pte_0_1_vbase = pte_vbase[0][1];
    wire [ADDR_W-1:0] dbg_pte_0_1_pbase = pte_pbase[0][1];

    wire dbg_pte_0_2_valid = pte_valid[0][2];
    wire dbg_pte_0_2_size = pte_size[0][2];
    wire [ADDR_W-1:0] dbg_pte_0_2_vbase = pte_vbase[0][2];
    wire [ADDR_W-1:0] dbg_pte_0_2_pbase = pte_pbase[0][2];

    wire dbg_pte_0_3_valid = pte_valid[0][3];
    wire dbg_pte_0_3_size = pte_size[0][3];
    wire [ADDR_W-1:0] dbg_pte_0_3_vbase = pte_vbase[0][3];
    wire [ADDR_W-1:0] dbg_pte_0_3_pbase = pte_pbase[0][3];

    wire dbg_pte_1_0_valid = pte_valid[1][0];
    wire dbg_pte_1_0_size = pte_size[1][0];
    wire [ADDR_W-1:0] dbg_pte_1_0_vbase = pte_vbase[1][0];
    wire [ADDR_W-1:0] dbg_pte_1_0_pbase = pte_pbase[1][0];

    wire dbg_pte_1_2_valid = pte_valid[1][2];
    wire dbg_pte_1_2_size = pte_size[1][2];
    wire [ADDR_W-1:0] dbg_pte_1_2_vbase = pte_vbase[1][2];
    wire [ADDR_W-1:0] dbg_pte_1_2_pbase = pte_pbase[1][2];

endmodule
