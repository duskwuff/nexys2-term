`default_nettype none

module cozy_memory_test ();

`include "testbench-helpers.v"

`CLOCK(clk, 1);

reg [12:0] addr = 0;
reg [15:0] din = 0;
reg [1:0] bwe = 0;
wire [15:0] dout;

cozy_memory #( .DEPTH(4) ) UUT (
    .clk    (clk),
    .addr   (addr),
    .din    (din),
    .bwe    (bwe),
    .dout   (dout)
);

initial begin

`WAIT_GSR;

addr <= 12'h0000; din <= 16'h1234; bwe <= 2'b11; #1;
addr <= 12'h0002; din <= 16'h5678; bwe <= 2'b11; #1;
addr <= 12'h0004; din <= 16'h9abc; bwe <= 2'b11; #1;
addr <= 12'h0006; din <= 16'hcdef; bwe <= 2'b11; #1;

`IS(UUT.ram_hi[0], 8'h12); `IS(UUT.ram_lo[0], 8'h34);
`IS(UUT.ram_hi[1], 8'h56); `IS(UUT.ram_lo[1], 8'h78);
`IS(UUT.ram_hi[2], 8'h9a); `IS(UUT.ram_lo[2], 8'hbc);
`IS(UUT.ram_hi[3], 8'hcd); `IS(UUT.ram_lo[3], 8'hef);

addr <= 12'h0000; din <= 16'hABCD; bwe <= 2'b01; #1
`IS(UUT.ram_hi[0], 8'h12); `IS(UUT.ram_lo[0], 8'hCD);

addr <= 12'h0001; din <= 16'hBCDE; bwe <= 2'b01; #1
`IS(UUT.ram_hi[0], 8'hDE); `IS(UUT.ram_lo[0], 8'hCD);

addr <= 12'h0000; bwe <= 2'b00; #1; `IS(dout, 16'hDECD);
addr <= 12'h0001; bwe <= 2'b00; #1; `IS(dout, 16'h00DE);
addr <= 12'h0002; bwe <= 2'b00; #1; `IS(dout, 16'h5678);

`DONE_TESTING;

end

endmodule
