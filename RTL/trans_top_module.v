module uart_top #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16,
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD       = 9600,
    parameter OVERSAMPLE = 16
)(
    input  wire clk,
    input  wire rst_n,
    // system interface
    input  wire tx_wr,
    input  wire [DATA_WIDTH-1:0] tx_wdata,
    output wire tx_full,
    input  wire rx_rd,
    output wire [DATA_WIDTH-1:0] rx_rdata,
    output wire rx_empty,
    // serial pins
    output wire tx_pin,
    input  wire rx_pin
);

    // internal wires
    wire tick;
    wire tx_fifo_wr;
    wire tx_fifo_full;
    wire [DATA_WIDTH-1:0] tx_fifo_din;
    wire tx_fifo_rd;
    wire [DATA_WIDTH-1:0] tx_fifo_dout;
    wire tx_fifo_empty;

    wire rx_fifo_wr;
    wire rx_fifo_full;
    wire [DATA_WIDTH-1:0] rx_fifo_din;
    wire rx_fifo_rd_i;
    wire [DATA_WIDTH-1:0] rx_fifo_dout;

    // baud generator
    baudgen #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD(BAUD),
        .OVERSAMPLE(OVERSAMPLE)
    ) u_baud (
        .clk(clk),
        .rst_n(rst_n),
        .tick(tick)
    );

    // tx fifo - system writes to tx_fifo using tx_wr
    assign tx_fifo_wr = tx_wr;
    assign tx_fifo_din = tx_wdata;
    assign tx_full = tx_fifo_full;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) u_tx_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr(tx_fifo_wr), .din(tx_fifo_din), .full(tx_fifo_full),
        .rd(tx_fifo_rd), .dout(tx_fifo_dout), .empty(tx_fifo_empty), .almost_full()
    );

    // uart tx
    reg tx_din_valid;
    wire tx_din_ready;
    wire tx_busy;
    wire tx_done_tick;

    // connect FIFO to TX: when FIFO not empty and TX idle, read from FIFO
    assign tx_fifo_rd = (!tx_fifo_empty) && !tx_busy && !tx_din_valid;

    // load data when FIFO read happens — latch data for TX
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_din_valid <= 1'b0;
        end else begin
            if (tx_fifo_rd) begin
                tx_din_valid <= 1'b1;
            end else if (tx_din_ready) begin
                tx_din_valid <= 1'b0;
            end
        end
    end

    // capture FIFO output when rd asserted
    reg [DATA_WIDTH-1:0] tx_din_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) tx_din_reg <= 0;
        else if (tx_fifo_rd) tx_din_reg <= tx_fifo_dout;
    end

    uart_tx #(
        .DATA_WIDTH(DATA_WIDTH),
        .OVERSAMPLE(OVERSAMPLE)
    ) u_tx (
        .clk(clk), .rst_n(rst_n),
        .din(tx_din_reg), .din_valid(tx_din_valid), .din_ready(tx_din_ready),
        .tx(tx_pin), .tick(tick),
        .tx_busy(tx_busy), .tx_done_tick(tx_done_tick)
    );

    // uart rx
    wire rx_done_tick;
    uart_rx #(
        .DATA_WIDTH(DATA_WIDTH),
        .OVERSAMPLE(OVERSAMPLE)
    ) u_rx (
        .clk(clk), .rst_n(rst_n),
        .rx(rx_pin), .tick(tick),
        .dout(rx_fifo_din), .dout_valid(rx_done_tick), .framing_error()
    );

    // rx fifo - write when rx_done_tick asserted
    assign rx_fifo_wr = rx_done_tick;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) u_rx_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr(rx_fifo_wr), .din(rx_fifo_din), .full(rx_fifo_full),
        .rd(rx_rd), .dout(rx_fifo_dout), .empty(rx_empty), .almost_full()
    );

    assign rx_rdata = rx_fifo_dout;

endmodule
