`default_nettype none

module cozy_registerfile_test ();

`include "testbench-helpers.v"

`CLOCK(clk, 1);
`TIMEOUT(10000);

reg [3:0] rD_sel, rS_sel;
reg [15:0] rD_in;
reg rD_we;
wire [15:0] rS_out, rD_out;

cozy_registerfile UUT (
    .clk    (clk),
    .rD_sel (rD_sel),
    .rD_we  (rD_we),
    .rD_in  (rD_in),
    .rD_out (rD_out),
    .rS_sel (rS_sel),
    .rS_out (rS_out)
);

integer i;

initial begin

`WAIT_GSR

for (i = 1; i <= 15; i = i + 1)
    UUT.R[i] = i * 16'h1111;

rD_sel = 4'h1; rS_sel = 4'h2; rD_we = 0;
#1; `IS(rD_out, 16'h1111); `IS(rS_out, 16'h2222);

rD_sel = 4'h0; rS_sel = 4'hf; rD_we = 0;
#1; `IS(rD_out, 16'h0000); `IS(rS_out, 16'hffff);

rD_sel = 4'h1; rD_in = 16'haa55; rD_we = 1;
#1; `IS(UUT.R[1], 16'haa55); `IS(rD_out, 16'haa55);

rD_sel = 4'h0; rD_in = 16'haa55; rD_we = 1;
#1; `IS(UUT.R[1], 16'haa55); `IS(rD_out, 16'h0000);

`DONE_TESTING

end

endmodule
