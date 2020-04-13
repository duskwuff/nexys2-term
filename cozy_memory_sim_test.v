`default_nettype none

module cozy_memory_sim_test ();

`include "testbench-helpers.v"

`CLOCK(clk, 1);

reg [15:0] addr = 0;
reg [15:0] din = 0;
reg [1:0] bwe = 0;
wire [15:0] dout;

cozy_memory_sim UUT (
    .clk    (clk),
    .addr   (addr),
    .din    (din),
    .bwe    (bwe),
    .dout   (dout)
);

initial begin

`WAIT_GSR;

`NOTE("Word read/write");

addr <= 16'h0000; bwe <= 2'b11; din <= 16'h1234; #1;
addr <= 16'h0002; bwe <= 2'b11; din <= 16'h5678; #1;
addr <= 16'h0004; bwe <= 2'b11; din <= 16'h9abc; #1;
addr <= 16'h0006; bwe <= 2'b11; din <= 16'hcdef; #1;

addr <= 16'h0000; bwe <= 2'b00; #1; `IS(dout, 16'h1234);
addr <= 16'h0002; bwe <= 2'b00; #1; `IS(dout, 16'h5678);
addr <= 16'h0004; bwe <= 2'b00; #1; `IS(dout, 16'h9abc);
addr <= 16'h0006; bwe <= 2'b00; #1; `IS(dout, 16'hcdef);


`NOTE("Byte read/write");

addr <= 16'h0000; bwe <= 2'b11; din <= 16'h1234; #1;
addr <= 16'h0002; bwe <= 2'b11; din <= 16'h5678; #1;

addr <= 16'h0000; bwe <= 2'b00; #1; `IS(dout, 16'h1234);
addr <= 16'h0001; bwe <= 2'b00; #1; `IS(dout, 16'h0012);
addr <= 16'h0002; bwe <= 2'b00; #1; `IS(dout, 16'h5678);
addr <= 16'h0003; bwe <= 2'b00; #1; `IS(dout, 16'h0056);

addr <= 16'h0000; bwe <= 2'b01; din <= 16'h4321; #1;
addr <= 16'h0000; bwe <= 2'b00; #1; `IS(dout, 16'h1221);
addr <= 16'h0001; bwe <= 2'b01; din <= 16'h5432; #1;
addr <= 16'h0000; bwe <= 2'b00; #1; `IS(dout, 16'h3221);


`NOTE("Wraparound tests");
// BONUS NOTE: This part differs from cozy_memory_test because the memory is
// a lot smaller

addr <= 16'h0100; bwe <= 2'b11; din <= 16'h1000; #1;
addr <= 16'h0200; bwe <= 2'b11; din <= 16'h2000; #1;
addr <= 16'h0300; bwe <= 2'b11; din <= 16'h3000; #1;
addr <= 16'h0400; bwe <= 2'b11; din <= 16'h4000; #1;

addr <= 16'h0000; bwe <= 2'b00; #1; `IS(dout, 16'h4000);
addr <= 16'h0100; bwe <= 2'b00; #1; `IS(dout, 16'h1000);
addr <= 16'h0200; bwe <= 2'b00; #1; `IS(dout, 16'h2000);
addr <= 16'h0300; bwe <= 2'b00; #1; `IS(dout, 16'h3000);
addr <= 16'h0400; bwe <= 2'b00; #1; `IS(dout, 16'h4000);


`DONE_TESTING;

end

endmodule
