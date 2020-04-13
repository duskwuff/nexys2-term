`default_nettype none

module uart (
    input wire clk,

    input wire [15:0] addr,
    input wire [15:0] min,
    output reg [15:0] mout,
    input wire [1:0] bwe,

    input wire rs232_rx,
    output wire rs232_tx
);

reg [7:0] txdata;
reg txstrobe;
wire txready;
wire [7:0] rxdata;
wire rxstrobe;

reg rxwaiting;
reg [7:0] rxlatch;

uart_impl #(
    .DIVIDER (139)
) IMPL (
    .clk        (clk),
    .rx         (rs232_rx),
    .tx         (rs232_tx),
    .txdata     (txdata),
    .txstrobe   (txstrobe),
    .txready    (txready),
    .rxdata     (rxdata),
    .rxstrobe   (rxstrobe)
);

always @(posedge clk) begin
    if (bwe[0] && addr[3:0] == 4'h0) begin
        txdata <= min[7:0];
        txstrobe <= 1;
    end else
        txstrobe <= 0;

    if (rxstrobe) begin
        rxwaiting <= 1;
        rxlatch <= rxdata;
    end else if (bwe[0] && (addr[3:0] == 4'h2)) // clear rxwaiting
        rxwaiting <= 0;

    case (addr[3:0])
        4'h0: mout <= { 8'b0, rxlatch };
        4'h2: mout <= { 15'b0, rxwaiting };
        4'h4: mout <= { 15'b0, txready };
        default: mout <= 16'hffff;
    endcase
end

endmodule
