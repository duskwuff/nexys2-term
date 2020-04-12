`default_nettype none

module cozy_condition_evaluator (
    input wire [15:0] insn,
    input wire [2:0] cond,
    output reg out
);

wire cZ = cond[2];
wire cN = cond[1];
wire cC = cond[0];

always @(*)
    case (insn[11:9])
        3'b000: out =  cZ;        // eq
        3'b001: out = !cZ;        // ne
        3'b010: out =  cN;        // lt
        3'b011: out = !cN;        // ge
        3'b100: out =  cN ||  cZ; // le
        3'b101: out = !cN || !cZ; // gt
        3'b110: out =   0;        // FIXME: unused
        3'b111: out =   1;        // always
    endcase

endmodule
