`default_nettype none

module cozy_alu (
    input wire [15:0] rD,
    input wire [15:0] rS,
    input wire carry_in,
    input wire [3:0] op,
    output wire [15:0] out,
    output wire carry_out
);

reg [16:0] result;

//synthesis translate_off
reg [23:0] opcode;
always @(*)
    case (op)
        'h0: opcode = "MOV";
        'h1: opcode = "AND";
        'h2: opcode = "OR";
        'h3: opcode = "XOR";
        'h4: opcode = "SHR";
        'h5: opcode = "SRC";
        'h6: opcode = "SWP";
        'h7: opcode = "NOT";

        'h8: opcode = "ADD";
        'h9: opcode = "ADC";
        'hA: opcode = "INC";
        'hB: opcode = "DEC";
        'hC: opcode = "SUB";
        'hD: opcode = "SBC";
        'hE: opcode = "NEG";
        'hF: opcode = "???";
    endcase
//synthesis translate_on

always @(*)
    case (op)
        'h0: result = {1'b0, rS};
        'h1: result = {1'b0, rD & rS};
        'h2: result = {1'b0, rD | rS};
        'h3: result = {1'b0, rD ^ rS};
        'h4: result = {rS[0], 1'b0,     rS[15:1]};
        'h5: result = {rS[0], carry_in, rS[15:1]};
        'h6: result = {1'b0, rS[7:0], rS[15:8]};
        'h7: result = {1'b0, ~rS};

        'h8: result = rD + rS;
        'h9: result = rD + rS + {16'b0, carry_in};
        'ha: result = {rS + 17'd1};
        'hb: result = {rS - 17'd1};
        'hc: result = rD - rS;
        'hd: result = rD - rS - {16'b0, carry_in};
        'he: result = {17'd0 - rS};
        'hf: result = 17'd0; // unused
    endcase

assign carry_out = result[16];
assign out = result[15:0];

endmodule
