import cpu_defs::*;

module write_buffer (
    input wire clk,
    input wire rst,
    input wire push_valid,
    input wire [ADDR_W-1:0] push_addr,
    input wire [DATA_W-1:0] push_data,
    output wire full,
    output wire empty,
    output wire pop_valid,
    output wire [ADDR_W-1:0] pop_addr,
    output wire [DATA_W-1:0] pop_data,
    input wire pop_ready
);
    reg [ADDR_W-1:0] addr_mem [0:WRITE_BUFFER_DEPTH-1];
    reg [DATA_W-1:0] data_mem [0:WRITE_BUFFER_DEPTH-1];
    reg [WRITE_BUFFER_PTR_W-1:0] head;
    reg [WRITE_BUFFER_PTR_W-1:0] tail;
    reg [WRITE_BUFFER_PTR_W:0] count;
    integer i;

    assign full = (count == WRITE_BUFFER_DEPTH);
    assign empty = (count == 0);
    assign pop_valid = !empty;
    assign pop_addr = addr_mem[head];
    assign pop_data = data_mem[head];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            for (i = 0; i < WRITE_BUFFER_DEPTH; i = i + 1) begin
                addr_mem[i] <= 0;
                data_mem[i] <= 0;
            end
        end else begin
            case ({push_valid && !full, pop_ready && pop_valid})
                2'b10: begin
                    addr_mem[tail] <= push_addr;
                    data_mem[tail] <= push_data;
                    tail <= (tail == WRITE_BUFFER_DEPTH - 1) ? 0 : tail + 1'b1;
                    count <= count + 1'b1;
                end
                2'b01: begin
                    head <= (head == WRITE_BUFFER_DEPTH - 1) ? 0 : head + 1'b1;
                    count <= count - 1'b1;
                end
                2'b11: begin
                    addr_mem[tail] <= push_addr;
                    data_mem[tail] <= push_data;
                    tail <= (tail == WRITE_BUFFER_DEPTH - 1) ? 0 : tail + 1'b1;
                    head <= (head == WRITE_BUFFER_DEPTH - 1) ? 0 : head + 1'b1;
                end
                default: begin
                end
            endcase
        end
    end
endmodule

