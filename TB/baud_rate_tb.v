module baud_tb;

    reg clk;
    reg rst_n;
    wire tick;

    // DUT
    baudgen #(
        .CLOCK_FREQ(50_000_000),
        .BAUD(9600),
        .OVERSAMPLE(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tick(tick)
    );

    // clock 50 MHz → 20ns
    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        $dumpfile("baud_tb.vcd");
        $dumpvars(0, baud_tb);

        rst_n = 0;
        #100;
        rst_n = 1;

        #100000;  // 100us to clearly see tick pulses
        $finish;
    end

endmodule

