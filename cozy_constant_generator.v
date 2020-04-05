`default_nettype none

module cozy_constant_generator (
    input wire [15:0] insn,
    output reg [15:0] out
);

always @(*)
    case (insn[13:12])
        2'b00: out = { 8'h00, insn[7:0] };
        2'b01: out = { 8'hff, insn[7:0] };
        2'b10: out = { insn[7:0], 8'h00 };
        2'b11: out = { insn[7:0], 8'hff };
    endcase

endmodule
