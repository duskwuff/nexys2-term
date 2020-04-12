`default_nettype none

module cozy_constant_generator_test ();

`include "testbench-helpers.v"

reg [15:0] insn;
wire [15:0] out;

cozy_constant_generator UUT (
    .insn   (insn),
    .out    (out)
);

initial begin

`WAIT_GSR;

`define CASE(_insn, _out) insn <= _insn; #1; `IS(out, _out);

`CASE(16'h0112, 16'h0012);
`CASE(16'h1112, 16'hff12);
`CASE(16'h2112, 16'h1200);
`CASE(16'h3112, 16'h12ff);

`DONE_TESTING

end

endmodule
