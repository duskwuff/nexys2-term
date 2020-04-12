`default_nettype none

module cozy_cpu_init_test ();

`include "testbench-helpers.v"

`CLOCK(clk, 1);
`TIMEOUT(10000);

reg nrst;

wire [1:0] bwe;
wire [15:0] addr, drd, dwr;

cozy_cpu UUT (
    .clk        (clk),
    .reset_n    (nrst),

    .mem_addr   (addr),
    .mem_bwe    (bwe),
    .mem_dout   (dwr),
    .mem_din    (drd)
);

cozy_memory #(
    .BITS (8),
    .INIT_LO    ("../cozy_cpu_init_test.lo.mem"),
    .INIT_HI    ("../cozy_cpu_init_test.hi.mem")
) MEM (
    .clk        (clk),
    .addr       (addr),
    .bwe        (bwe),
    .din        (dwr),
    .dout       (drd)
);

initial begin

`WAIT_GSR;

// reset
nrst = 0; #1; nrst = 1; #1;

// run a bit and make sure the program ran
#5;
`IS(UUT.state,  'b110);
`IS(UUT.REG.r1, 16'hAA55);
`DONE_TESTING;

end

endmodule
