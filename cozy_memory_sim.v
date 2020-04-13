`default_nettype none

module cozy_memory_sim (
    input wire clk,
    input wire [15:0] addr,
    input wire [15:0] din,
    input wire [1:0] bwe,
    output wire [15:0] dout
);

reg [1:0] int_bwe;
reg [15:0] int_din;
reg [15:0] int_dout;

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

reg [7:0] ram_hi [511:0], ram_lo [511:0];
always @(posedge clk) begin
    if (int_bwe[1]) ram_hi[addr[9:1]] <= int_din[15:8];
    if (int_bwe[0]) ram_lo[addr[9:1]] <= int_din[7:0];
    int_dout <= { ram_hi[addr[9:1]], ram_lo[addr[9:1]] };
end

assign dout = latched_addr_0 ? { 8'b0, int_dout[15:8] } : { int_dout[15:0] };

endmodule
