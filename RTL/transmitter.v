module uart_tx #(
    parameter DATA_WIDTH = 8,
    parameter OVERSAMPLE = 16
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [DATA_WIDTH-1:0] din,
    input  wire din_valid,     // when asserted and idle, load din
    output reg  din_ready,     // indicates tx accepted data
    output reg  tx,            // serial output (idle = 1)
    input  wire tick,          // 1 when one oversample-clock period passed (i.e. 1/16th bit)
    output reg  tx_busy,
    output reg  tx_done_tick
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [3:0] bit_cnt; // up to 8
    reg [$clog2(OVERSAMPLE)-1:0] tick_cnt;
    reg [DATA_WIDTH-1:0] shift_reg;

    // default values
    initial begin
        tx = 1'b1;
        state = IDLE;
        tx_busy = 1'b0;
        tx_done_tick = 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx <= 1'b1;
            tx_busy <= 1'b0;
            tx_done_tick <= 1'b0;
            din_ready <= 1'b0;
            bit_cnt <= 0;
            tick_cnt <= 0;
            shift_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            // default single-cycle pulses
            tx_done_tick <= 1'b0;
            din_ready <= 1'b0;

            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    tick_cnt <= 0;
                    bit_cnt <= 0;
                    if (din_valid) begin
                        // accept data and start
                        shift_reg <= din;
                        tx_busy <= 1'b1;
                        state <= START;
                    end
                end

                START: begin
                    // drive start bit = 0
                    tx <= 1'b0;
                    if (tick) begin
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt <= 0;
                            bit_cnt <= 0;
                            state <= DATA;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                DATA: begin
                    // send LSB first
                    tx <= shift_reg[0];
                    if (tick) begin
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt <= 0;
                            shift_reg <= {1'b0, shift_reg[DATA_WIDTH-1:1]}; // shift right
                            if (bit_cnt == DATA_WIDTH-1) begin
                                bit_cnt <= 0;
                                state <= STOP;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (tick) begin
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt <= 0;
                            tx_busy <= 1'b0;
                            tx_done_tick <= 1'b1; // one-cycle pulse
                            state <= IDLE;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase

            // din_ready when we just accepted data in IDLE transit
            if (state == START && !tx_busy) begin
                // no-op (this case should not occur)
            end

            // accept din only in IDLE (so higher-level FIFO should present data when din_ready asserted)
            if ((state == IDLE) && din_valid) begin
                din_ready <= 1'b1; // will start immediately
            end
        end
    end

endmodule
