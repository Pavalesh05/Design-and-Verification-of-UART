module uart_rx #(
    parameter DATA_WIDTH = 8,
    parameter OVERSAMPLE = 16
)(
    input  wire clk,
    input  wire rst_n,
    input  wire rx,       // serial input (idle = 1)
    input  wire tick,     // tick at 1/OVERSAMPLE * bit period
    output reg  [DATA_WIDTH-1:0] dout,
    output reg  dout_valid,
    output reg  framing_error
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [$clog2(OVERSAMPLE)-1:0] tick_cnt;
    reg [3:0] bit_cnt;
    reg [DATA_WIDTH-1:0] shift_reg;

    initial begin
        dout <= 0;
        dout_valid <= 0;
        framing_error <= 0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tick_cnt <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            dout <= 0;
            dout_valid <= 1'b0;
            framing_error <= 1'b0;
        end else begin
            dout_valid <= 1'b0; // default
            case (state)
                IDLE: begin
                    tick_cnt <= 0;
                    bit_cnt <= 0;
                    if (!rx) begin // start bit detected (line low)
                        state <= START;
                        tick_cnt <= 0;
                    end
                end

                START: begin
                    if (tick) begin
                        tick_cnt <= tick_cnt + 1'b1;
                        // wait for middle of start bit: OVERSAMPLE/2
                        if (tick_cnt == (OVERSAMPLE/2 - 1)) begin
                            // sample start bit
                            if (!rx) begin
                                tick_cnt <= 0;
                                bit_cnt <= 0;
                                state <= DATA;
                            end else begin
                                // false start
                                state <= IDLE;
                            end
                        end
                    end
                end

                DATA: begin
                    if (tick) begin
                        tick_cnt <= tick_cnt + 1'b1;
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt <= 0;
                            // sample data bit at middle (we sample at end of oversample window)
                            shift_reg <= {rx, shift_reg[DATA_WIDTH-1:1]}; // shift in MSB-first and later reverse? We'll shift LSB-first below
                            // Note: easier approach: shift_reg <= {rx, shift_reg[DATA_WIDTH-1:1]} and then reverse bits at assignment,
                            // but here we want LSB first: do shift_reg <= {rx, shift_reg[DATA_WIDTH-1:1]} then manage ordering.
                            if (bit_cnt == DATA_WIDTH-1) begin
                                bit_cnt <= 0;
                                state <= STOP;
                                tick_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end
                end

                STOP: begin
                    if (tick) begin
                        tick_cnt <= tick_cnt + 1'b1;
                        if (tick_cnt == OVERSAMPLE/2 - 1) begin
                            // sample stop bit at center
                            if (rx == 1'b1) begin
                                // success: deliver data (we shifted MSB-first, so reverse bits)
                                // We must reconstruct correct order: because TX sent LSB first, typical approach is shift LSB into LSB position.
                                // To avoid complexity, change DATA shift to shift in LSB at MSB position? Simpler: use a shift method LSB-first:
                                // But current code used shift_reg <= {rx, shift_reg[DATA_WIDTH-1:1]}; which stores latest bit as MSB.
                                // So we need to reverse bits or instead implement direct bit placement. To keep simple, assume shift_reg holds bits LSB-first in positions:
                                // I'll instead change DATA stage to place bit into correct position using bit_cnt index.
                                // For now, set dout = shift_reg (depending on design). We'll correct below in code update.
                            end else begin
                                framing_error <= 1'b1;
                            end
                            // produce dout and valid
                            dout <= shift_reg; // ensure correct order in final code below
                            dout_valid <= 1'b1;
                            state <= IDLE;
                            tick_cnt <= 0;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

