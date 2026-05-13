import cpu_defs::*;

module tlb (
    input wire clk,
    input wire rst,
    input wire lookup_valid,
    input wire [ADDR_W-1:0] lookup_vaddr,
    output reg hit,
    output reg [ADDR_W-1:0] paddr,
    output reg [PAGE_SIZE_W-1:0] page_size,
    input wire fill_valid,
    input wire [ADDR_W-1:0] fill_vbase,
    input wire [ADDR_W-1:0] fill_pbase,
    input wire [PAGE_SIZE_W-1:0] fill_page_size,
    input wire invalidate
);
    reg entry_valid [0:TLB_ENTRIES-1];
    reg [ADDR_W-1:0] entry_vbase [0:TLB_ENTRIES-1];
    reg [ADDR_W-1:0] entry_pbase [0:TLB_ENTRIES-1];
    reg [PAGE_SIZE_W-1:0] entry_size [0:TLB_ENTRIES-1];
    reg [TLB_IDX_W-1:0] replace_idx;

    integer i;

    function automatic match_entry;
        input [ADDR_W-1:0] vaddr;
        input [ADDR_W-1:0] base;
        input [PAGE_SIZE_W-1:0] size;
        begin
            if (size == PAGE_LARGE) begin
                match_entry = vaddr[ADDR_W-1:LARGE_PAGE_OFFSET_W] == base[ADDR_W-1:LARGE_PAGE_OFFSET_W];
            end else begin
                match_entry = vaddr[ADDR_W-1:SMALL_PAGE_OFFSET_W] == base[ADDR_W-1:SMALL_PAGE_OFFSET_W];
            end
        end
    endfunction

    function automatic [ADDR_W-1:0] apply_offset;
        input [ADDR_W-1:0] vaddr;
        input [ADDR_W-1:0] base;
        input [PAGE_SIZE_W-1:0] size;
        begin
            if (size == PAGE_LARGE) begin
                apply_offset = {base[ADDR_W-1:LARGE_PAGE_OFFSET_W], vaddr[LARGE_PAGE_OFFSET_W-1:0]};
            end else begin
                apply_offset = {base[ADDR_W-1:SMALL_PAGE_OFFSET_W], vaddr[SMALL_PAGE_OFFSET_W-1:0]};
            end
        end
    endfunction

    always @(*) begin
        hit = 1'b0;
        paddr = 0;
        page_size = PAGE_SMALL;
        for (i = 0; i < TLB_ENTRIES; i = i + 1) begin
            if (lookup_valid && entry_valid[i] && match_entry(lookup_vaddr, entry_vbase[i], entry_size[i])) begin
                hit = 1'b1;
                paddr = apply_offset(lookup_vaddr, entry_pbase[i], entry_size[i]);
                page_size = entry_size[i];
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            replace_idx <= 0;
            for (i = 0; i < TLB_ENTRIES; i = i + 1) begin
                entry_valid[i] <= 1'b0;
                entry_vbase[i] <= 0;
                entry_pbase[i] <= 0;
                entry_size[i] <= PAGE_SMALL;
            end
        end else if (invalidate) begin
            replace_idx <= 0;
            for (i = 0; i < TLB_ENTRIES; i = i + 1) begin
                entry_valid[i] <= 1'b0;
            end
        end else if (fill_valid) begin
            entry_valid[replace_idx] <= 1'b1;
            entry_vbase[replace_idx] <= fill_vbase;
            entry_pbase[replace_idx] <= fill_pbase;
            entry_size[replace_idx] <= fill_page_size;
            replace_idx <= (replace_idx == TLB_ENTRIES - 1) ? 0 : replace_idx + 1'b1;
        end
    end

    wire dbg_entry_0_valid = entry_valid[0];
    wire [ADDR_W-1:0] dbg_entry_0_vbase = entry_vbase[0];
    wire [ADDR_W-1:0] dbg_entry_0_pbase = entry_pbase[0];
    wire dbg_entry_0_size = entry_size[0];

    wire dbg_entry_1_valid = entry_valid[1];
    wire [ADDR_W-1:0] dbg_entry_1_vbase = entry_vbase[1];
    wire [ADDR_W-1:0] dbg_entry_1_pbase = entry_pbase[1];
    wire dbg_entry_1_size = entry_size[1];

    wire dbg_entry_2_valid = entry_valid[2];
    wire [ADDR_W-1:0] dbg_entry_2_vbase = entry_vbase[2];
    wire [ADDR_W-1:0] dbg_entry_2_pbase = entry_pbase[2];
    wire dbg_entry_2_size = entry_size[2];

    wire dbg_entry_3_valid = entry_valid[3];
    wire [ADDR_W-1:0] dbg_entry_3_vbase = entry_vbase[3];
    wire [ADDR_W-1:0] dbg_entry_3_pbase = entry_pbase[3];
    wire dbg_entry_3_size = entry_size[3];

endmodule

