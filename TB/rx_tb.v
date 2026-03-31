`timescale 1ns/1ps
module uart_rx_tb;

    reg clk;
    reg rst_n;
    reg rx;
    wire [7:0] dout;
    wire dout_valid;
    wire tick;
    wire framing_error;

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

    // rx
    uart_rx dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .tick(tick),
        .dout(dout),
        .dout_valid(dout_valid),
        .framing_error(framing_error)
    );

    initial begin
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_tb);

        rst_n = 0;
        rx = 1; // idle
        #200;
        rst_n = 1;

        #5000;

        send_byte(8'h41); // send ‘A’

        #200000;
        $finish;
    end

    // task to generate serial waveform
    task send_byte(input [7:0] b);
        integer i;
    begin
        // Start bit
        drive_bit(0);

        // 8 data bits (LSB first)
        for (i=0; i<8; i=i+1)
            drive_bit(b[i]);

        // Stop bit
        drive_bit(1);
    end
    endtask

    // drive one bit for exactly 1 bit-time (16 ticks)
    task drive_bit(input bitval);
        integer j;
    begin
        rx = bitval;
        for (j=0; j<16; j=j+1)
            @(posedge tick);
    end
    endtask

endmodule
