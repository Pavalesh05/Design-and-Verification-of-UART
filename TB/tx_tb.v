`timescale 1ns/1ps
module uart_tx_tb;

    reg clk;
    reg rst_n;
    reg [7:0] din;
    reg din_valid;
    wire din_ready;
    wire tx;
    wire tick;
    wire tx_busy, tx_done_tick;

    // clock
    initial clk = 0;
    always #10 clk = ~clk;

    // baud generator
    baudgen #(
        .CLOCK_FREQ(50_000_000),
        .BAUD(9600),
        .OVERSAMPLE(16)
    ) baud (
        .clk(clk),
        .rst_n(rst_n),
        .tick(tick)
    );

    // tx
    uart_tx dut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .din_valid(din_valid),
        .din_ready(din_ready),
        .tx(tx),
        .tick(tick),
        .tx_busy(tx_busy),
        .tx_done_tick(tx_done_tick)
    );

    initial begin
        $dumpfile("uart_tx_tb.vcd");
        $dumpvars(0, uart_tx_tb);

        rst_n = 0;
        din_valid = 0;
        din = 8'h00;
        #200;
        rst_n = 1;

        #3000;  // allow some ticks

        // transmit one byte
        @(posedge clk);
        din = 8'h41;
        din_valid = 1;
        @(posedge clk);
        din_valid = 0;

        #200000;
        $finish;
    end

endmodule
