`default_nettype none

module cozy_memory (
    input wire clk,
    input wire [15:0] addr,
    input wire [15:0] din,
    input wire [1:0] bwe,
    output wire [15:0] dout
);

wire [16-2:0] waddr = addr[16-1:1];

reg [1:0] int_bwe;
reg [15:0] int_din;
wire [15:0] int_dout;

reg latched_addr_0;
always @(posedge clk)
    latched_addr_0 <= addr[0];

always @(*) begin
    if (bwe == 2'b01 && addr[0] == 0) begin
        int_bwe = 2'b01;
        int_din = din;
    end else if (bwe == 2'b01 && addr[0] == 1) begin
        int_bwe = 2'b10;
        int_din = { din[7:0], 8'b0 };
    end else if (bwe == 2'b11) begin
        int_bwe = 2'b11;
        int_din = din;
    end else begin
        int_bwe = 2'b00;
        int_din = din;
    end
end

// Memory configuration: 16 KB as 8 x RAMB16_S2
genvar i;
generate
    for (i = 0; i < 16; i = i + 2) begin : gen
        RAMB16_S2 #(
            .WRITE_MODE ("READ_FIRST")
        ) bram (
            .CLK    (clk),
            .EN     (1'b1),
            .SSR    (1'b0),
            .ADDR   (addr[13:1]),
            .DI     ({ int_din[i + 1], int_din[i] }),
            .DO     ({ int_dout[i + 1], int_dout[i] }),
            .WE     (int_bwe[(i < 8) ? 0 : 1])
        );
    end
endgenerate

assign dout = latched_addr_0 ? { 8'b0, int_dout[15:8] } : { int_dout[15:0] };

endmodule
