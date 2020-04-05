`default_nettype none

module nexys2_cpu (
    input wire clk50,
    input wire [7:0] sw,
    input wire [3:0] btn,
    output wire [7:0] led,
    output wire [7:0] ssd_seg,
    output wire [3:0] ssd_an
);

wire clk;

DCM_SP #(
    .CLKFX_MULTIPLY (2),
    .CLKFX_DIVIDE   (10),
    .CLK_FEEDBACK   ("NONE")
) dcm (
    .CLKIN  (clk50),
    .CLKFX  (clk),
    .RST    (1'b0)
);

reg [31:0] ctr;
always @(posedge clk)
    ctr <= ctr + 1;

wire [15:0] pc;
wire [15:0] insn;
wire [3:0] state;
wire [7:0] outport;

cozy_cpu CPU (
    .clk        (clk),
    .reset_n    (!btn[0]),
    .inport     (sw),
    .outport    (outport),
    .out_pc     (pc),
    .out_state  (state),
    .out_insn   (insn)
);

assign led = outport;

/*
reg [15:0] ssd_val = 0;
seven_seg_driver SSD (
    .clk        (clk),
    .cke        (ctr[14:0] == 0),
    .blank      (0),
    .value      (ssd_val),
    .dp         (4'b0),
    .seg        (ssd_seg),
    .an         (ssd_an)
);
*/

endmodule
