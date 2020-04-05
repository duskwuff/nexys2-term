`default_nettype none

module cozy_alu_test ();

`include "testbench-helpers.v"

reg [15:0] r1, r2;
reg [3:0] op;
reg ci;

wire [15:0] out;
wire co;

cozy_alu UUT (
    .r1         (r1),
    .r2         (r2),
    .op         (op),
    .carry_in   (ci),
    .out        (out),
    .carry_out  (co)
);

initial begin

`WAIT_GSR;

`define CASE(_op, _ci, _r1, _r2, _co, _out) \
    {op, ci, r1, r2} <= {_op, _ci, _r1, _r2}; #1; `IS({co, out}, {_co, _out});

`NOTE("OR");
    `CASE(4'h0, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h0, 1'b1, 16'h1234, 16'h2345,  1'b0, 16'h3375);

`NOTE("AND");
    `CASE(4'h1, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h1, 1'b1, 16'h1234, 16'h2345,  1'b0, 16'h0204);

`NOTE("XOR");
    `CASE(4'h2, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h2, 1'b1, 16'h1234, 16'h2345,  1'b0, 16'h3171);

`NOTE("BIC");
    `CASE(4'h3, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h3, 1'b1, 16'h1234, 16'h2345,  1'b0, 16'h1030);

`NOTE("ADD");
    `CASE(4'h4, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h4, 1'b0, 16'h1234, 16'h2345,  1'b0, 16'h3579);
    `CASE(4'h4, 1'b1, 16'h1234, 16'h2345,  1'b0, 16'h3579); // carry ignored
    `CASE(4'h4, 1'b0, 16'hFFFF, 16'h0001,  1'b1, 16'h0000); // carry
    `CASE(4'h4, 1'b0, 16'hFFFF, 16'hFFFF,  1'b1, 16'hFFFE); // big carry

`NOTE("ADC");
    `CASE(4'h5, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h5, 1'b0, 16'h1234, 16'h2345,  1'b0, 16'h3579);
    `CASE(4'h5, 1'b1, 16'h1234, 16'h2345,  1'b0, 16'h357A); // carry in DOES affect ADC
    `CASE(4'h5, 1'b0, 16'hFFFF, 16'h0001,  1'b1, 16'h0000); // carry
    `CASE(4'h5, 1'b1, 16'hFFFF, 16'h0000,  1'b1, 16'h0000); // carry from carry
    `CASE(4'h5, 1'b0, 16'hFFFF, 16'hFFFF,  1'b1, 16'hFFFE); // carry some more
    `CASE(4'h5, 1'b1, 16'hFFFF, 16'hFFFF,  1'b1, 16'hFFFF); // carry even more

`NOTE("SUB");
    `CASE(4'h6, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h6, 1'b0, 16'h1000, 16'h0001,  1'b0, 16'h0fff);
    `CASE(4'h6, 1'b1, 16'h1000, 16'h0001,  1'b0, 16'h0fff); // carry ignored
    `CASE(4'h6, 1'b0, 16'h0000, 16'h0001,  1'b1, 16'hffff); // borrow
    `CASE(4'h6, 1'b0, 16'hffff, 16'hffff,  1'b0, 16'h0000); // not a borrow

`NOTE("SBC");
    `CASE(4'h7, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h7, 1'b0, 16'h1000, 16'h0001,  1'b0, 16'h0fff);
    `CASE(4'h7, 1'b1, 16'h1000, 16'h0001,  1'b0, 16'h0ffe); // carry = subtract one more
    `CASE(4'h7, 1'b0, 16'h0000, 16'h0001,  1'b1, 16'hffff); // borrow
    `CASE(4'h7, 1'b0, 16'hffff, 16'hffff,  1'b0, 16'h0000); // not a borrow
    `CASE(4'h7, 1'b1, 16'hffff, 16'hffff,  1'b1, 16'hffff); // borrow from zero

`NOTE("NOT");
    `CASE(4'h8, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'hFFFF);
    `CASE(4'h8, 1'b0, 16'h0000, 16'hAAAA,  1'b0, 16'h5555);

`NOTE("NEG");
    `CASE(4'h9, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0000);
    `CASE(4'h9, 1'b0, 16'h0000, 16'h0001,  1'b1, 16'hFFFF); // NEG sets carry as a side effect for nonzero results
    `CASE(4'h9, 1'b0, 16'h0000, 16'hAAAA,  1'b1, 16'h5556); // this isn't intentional but it's cute so I'll keep it

`NOTE("INC");
    `CASE(4'hA, 1'b0, 16'h0000, 16'h0000,  1'b0, 16'h0001);
    `CASE(4'hA, 1'b1, 16'h0000, 16'h0000,  1'b0, 16'h0001);
    `CASE(4'hA, 1'b1, 16'h0000, 16'h1234,  1'b0, 16'h1235);
    `CASE(4'hA, 1'b0, 16'h0000, 16'hFFFF,  1'b1, 16'h0000);

`NOTE("DEC");
    `CASE(4'hB, 1'b0, 16'h0000, 16'h0000,  1'b1, 16'hFFFF);
    `CASE(4'hB, 1'b1, 16'h0000, 16'h0000,  1'b1, 16'hFFFF);
    `CASE(4'hB, 1'b1, 16'h0000, 16'h1234,  1'b0, 16'h1233);
    `CASE(4'hB, 1'b0, 16'h0000, 16'hFFFF,  1'b0, 16'hFFFE);

`NOTE("SHR");
    `CASE(4'hC, 1'b0, 16'h0000, 16'h1234,  1'b0, 16'h091A);
    `CASE(4'hC, 1'b1, 16'h0000, 16'h1234,  1'b0, 16'h091A);
    `CASE(4'hC, 1'b0, 16'h0000, 16'h2345,  1'b1, 16'h11A2);

`NOTE("SHRC");
    `CASE(4'hD, 1'b0, 16'h0000, 16'h1234,  1'b0, 16'h091A);
    `CASE(4'hD, 1'b1, 16'h0000, 16'h1234,  1'b0, 16'h891A);
    `CASE(4'hD, 1'b0, 16'h0000, 16'h2345,  1'b1, 16'h11A2);

`NOTE("SHL");
    `CASE(4'hE, 1'b0, 16'h0000, 16'h1234,  1'b0, 16'h2468);
    `CASE(4'hE, 1'b1, 16'h0000, 16'h1234,  1'b0, 16'h2468);
    `CASE(4'hE, 1'b0, 16'h0000, 16'h89AB,  1'b1, 16'h1356);
                               
`NOTE("SHLC");                 
    `CASE(4'hF, 1'b0, 16'h0000, 16'h1234,  1'b0, 16'h2468);
    `CASE(4'hF, 1'b1, 16'h0000, 16'h1234,  1'b0, 16'h2469);
    `CASE(4'hF, 1'b0, 16'h0000, 16'h89AB,  1'b1, 16'h1356);

`DONE_TESTING;

end

endmodule
