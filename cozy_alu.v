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
        'h0: opcode = "OR";
        'h1: opcode = "AND";
        'h2: opcode = "XOR";
        'h3: opcode = "BIC";
        'h4: opcode = "ADD";
        'h5: opcode = "ADC";
        'h6: opcode = "SUB";
        'h7: opcode = "SBC";
        'h8: opcode = "NOT";
        'h9: opcode = "NEG";
        'hA: opcode = "INC";
        'hB: opcode = "DEC";
        'hC: opcode = "SHR";
        'hD: opcode = "SRC";
        'hE: opcode = "SHL";
        'hF: opcode = "SLC";
    endcase
//synthesis translate_on

always @(*)
    case (op)
        'h0: result = {1'b0, rD | rS};
        'h1: result = {1'b0, rD & rS};
        'h2: result = {1'b0, rD ^ rS};
        'h3: result = {1'b0, rD & ~rS};
        'h4: result = rD + rS;
        'h5: result = rD + rS + {16'b0, carry_in};
        'h6: result = rD - rS;
        'h7: result = rD - rS - {16'b0, carry_in};
        'h8: result = {1'b0, ~rS};
        'h9: result = {17'd0 - rS};
        'ha: result = {rS + 17'd1};
        'hb: result = {rS - 17'd1};
        'hc: result = {rS[0], 1'b0,     rS[15:1]};
        'hd: result = {rS[0], carry_in, rS[15:1]};
        'he: result = {rS[15], rS[14:0],  1'b0};
        'hf: result = {rS[15], rS[14:0],  carry_in};
    endcase

assign carry_out = result[16];
assign out = result[15:0];

endmodule
