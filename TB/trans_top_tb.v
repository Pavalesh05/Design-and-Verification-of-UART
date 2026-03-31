module uart_tb;
    parameter DATA_WIDTH = 8;
    parameter CLOCK_FREQ = 50_000_000;
    parameter BAUD = 9600;
    parameter OVERSAMPLE = 16;

    reg clk;
    reg rst_n;

    // top signals
    reg tx_wr;
    reg [DATA_WIDTH-1:0] tx_wdata;
    wire tx_full;
    reg rx_rd;
    wire [DATA_WIDTH-1:0] rx_rdata;
    wire rx_empty;
    wire tx_pin;
    wire rx_pin;

    // instantiate top
    uart_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(16),
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD(BAUD),
        .OVERSAMPLE(OVERSAMPLE)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .tx_wr(tx_wr), .tx_wdata(tx_wdata), .tx_full(tx_full),
        .rx_rd(rx_rd), .rx_rdata(rx_rdata), .rx_empty(rx_empty),
        .tx_pin(tx_pin), .rx_pin(rx_pin)
    );

    // loopback connection: direct TX->RX in testbench
    assign rx_pin = tx_pin;

    // clock generation: 50 MHz => 20 ns period
    initial clk = 0;
    always #10 clk = ~clk;

    integer i;

    initial begin
        // waveform dump (for VCD)
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
    end

    initial begin
        // init
        rst_n = 0;
        tx_wr = 0;
        tx_wdata = 0;
        rx_rd = 0;

        // apply reset for 200 ns (ensure baud counter gets reset)
        #200;
        rst_n = 1;

        // wait a little for stable operation (let some baud ticks appear)
        #2000; // 2us

        // write bytes one by one (41h, 42h, 43h)
        write_byte(8'h41);
        // wait between writes so FIFO & tx handles data
        #20000; // 20us
        write_byte(8'h42);
        #20000;
        write_byte(8'h43);

        // wait for transmissions to complete
        #200000; // 200us

        // read back from RX FIFO and display
        while (!rx_empty) begin
            rx_rd = 1;
            #20;
            $display("time=%0t: read rx = 0x%0h", $time, rx_rdata);
            rx_rd = 0;
            #2000;
        end

        #1000;
        $display("Simulation complete");
        $finish;
    end

    task write_byte(input [7:0] b);
    begin
        @(posedge clk);
        tx_wdata = b;
        tx_wr = 1;
        @(posedge clk);
        tx_wr = 0;
        $display("time=%0t: wrote tx = 0x%0h", $time, b);
    end
    endtask

endmodule

