`default_nettype none

module cozy_registerfile (
    input wire clk,

    input wire [3:0] rD_sel,
    input wire rD_we,
    input wire [15:0] rD_in,
    output wire [15:0] rD_out,

    input wire [3:0] rS_sel,
    output wire [15:0] rS_out
);

reg [15:0] R [15:1];

assign rS_out = (rS_sel == 0) ? 16'b0 : R[rS_sel];
assign rD_out = (rD_sel == 0) ? 16'b0 : R[rD_sel];

always @(posedge clk)
    if (rD_we && rD_sel != 0)
        R[rD_sel] = rD_in;

//synthesis translate_off
wire [15:0] r1 = R[1], r2 = R[2], r3 = R[3], r4 = R[4], r5 = R[5];
wire [15:0] r6 = R[6], r7 = R[7], r8 = R[8], r9 = R[9], r10 = R[10];
wire [15:0] r11 = R[11], r12 = R[12], r13 = R[13], r14 = R[14], r15 = R[15];
//synthesis translate_on

endmodule
