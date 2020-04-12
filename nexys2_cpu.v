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

// verilator lint_off PINMISSING
DCM_SP #(
    .CLKFX_MULTIPLY (5),
    .CLKFX_DIVIDE   (10),
    .CLK_FEEDBACK   ("NONE")
) dcm (
    .CLKIN  (clk50),
    .CLK0   (),
    .CLKFX  (clk),
    .RST    (1'b0)
);
// verilator lint_on PINMISSING

reg [31:0] ctr;
always @(posedge clk)
    ctr <= ctr + 1;

wire [15:0] addr;
wire [15:0] drd, dwr;
wire [1:0] bwe;

wire ce_mem   = addr < 16'h2000;
wire [15:0] drd_mem;
reg old_ce_mem;
always @(posedge clk) old_ce_mem <= ce_mem;

wire ce_debug = addr >= 16'hff80;
wire [15:0] drd_debug;
reg old_ce_debug;
always @(posedge clk) old_ce_debug <= ce_debug;

assign drd = (
    old_ce_mem ? drd_mem :
    old_ce_debug ? drd_debug :
    16'h0000
);

cozy_memory #(
    .BITS (13), // 8 KB
    .INIT_HI    ("blinker.hi.mem"),
    .INIT_LO    ("blinker.lo.mem")
) MEM (
    .clk        (clk),
    .addr       (addr),
    .bwe        (ce_mem ? bwe : 2'b0),
    .din        (dwr),
    .dout       (drd_mem)
);

wire [15:0] ssd;

debug_adapter DEBUG (
    .clk        (clk),
    .addr       (addr),
    .bwe        (ce_debug ? bwe : 2'b0),
    .din        (dwr),
    .dout       (drd_debug),

    .sw         (sw),
    .btn        (btn),
    .led        (led),
    .ssd        (ssd)
);

cozy_cpu CPU (
    .clk        (clk),
    .reset_n    (!btn[0]),
    .mem_addr   (addr),
    .mem_bwe    (bwe),
    .mem_din    (drd),
    .mem_dout   (dwr)
);

seven_seg_driver SSD (
    .clk        (clk),
    .cke        (ctr[14:0] == 0),
    .blank      (0),
    .value      (ssd),
    .dp         (4'b0),
    .seg        (ssd_seg),
    .an         (ssd_an)
);

endmodule
