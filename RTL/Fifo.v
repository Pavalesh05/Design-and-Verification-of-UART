amodule sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16
)(
    input  wire clk,
    input  wire rst_n,      // active low
    input  wire wr,
    input  wire [DATA_WIDTH-1:0] din,
    output wire full,
    input  wire rd,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire empty,
    output wire almost_full
);
    localparam AW = $clog2(DEPTH);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW:0] wr_ptr; // extra bit for full detection
    reg [AW:0] rd_ptr;
    wire [AW-1:0] wr_addr = wr_ptr[AW-1:0];
    wire [AW-1:0] rd_addr = rd_ptr[AW-1:0];

    // full when next write would make pointers equal with MSB different
    assign full = ( (wr_ptr[AW] != rd_ptr[AW]) && (wr_addr == rd_addr) );
    assign empty = (wr_ptr == rd_ptr);
    // almost full: one location left
    assign almost_full = (( (wr_ptr - rd_ptr) >= (DEPTH-1) ));

    // write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {AW+1{1'b0}};
        end else begin
            if (wr && !full) begin
                mem[wr_addr] <= din;
                wr_ptr <= wr_ptr + 1'b1;
            end
        end
    end

    // read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= {AW+1{1'b0}};
            dout <= {DATA_WIDTH{1'b0}};
        end else begin
            if (rd && !empty) begin
                dout <= mem[rd_addr];
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

endmodule
