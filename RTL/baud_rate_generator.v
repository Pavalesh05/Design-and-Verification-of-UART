module baudgen #(
    parameter integer CLOCK_FREQ = 50_000_000,
    parameter integer BAUD       = 9600,
    parameter integer OVERSAMPLE = 16
) (
    input  wire clk,
    input  wire rst_n,    // active low
    output reg  tick      // one-cycle pulse every (CLOCK_FREQ/(BAUD*OVERSAMPLE)) clocks
);

    localparam integer DIV = (CLOCK_FREQ + (BAUD*OVERSAMPLE)/2) / (BAUD*OVERSAMPLE); // rounded
    localparam integer NB  = $clog2(DIV+1);

    reg [NB-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt  <= {NB{1'b0}};
            tick <= 1'b0;
        end else begin
            if (cnt == DIV-1) begin
                cnt  <= {NB{1'b0}};
                tick <= 1'b1;
            end else begin
                cnt  <= cnt + 1'b1;
                tick <= 1'b0;
            end
        end
    end

endmodule


