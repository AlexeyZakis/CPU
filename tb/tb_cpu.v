module tb_cpu;
    reg clk;
    reg rst;

    cpu cpu (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cpu);
    end

    initial begin
        clk = 1'b0;
        forever #1 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        #2;
        rst = 1'b0;

        #200;
        $finish;
    end

endmodule

