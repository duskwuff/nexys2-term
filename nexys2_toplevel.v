`default_nettype none

module nexys2_toplevel (
    input wire clk50,
    input wire clkSocket,
    input wire [7:0] sw,
    input wire [3:0] btn,

    output wire [7:0] led,
    output wire [7:0] ssd_seg,
    output wire [3:0] ssd_an,

    input wire rs232_rx,
    output wire rs232_tx,

    output wire [7:0] vgaRgb,
    output wire vgaHsync,
    output wire vgaVsync
);

wire clk,  clk_dcm;
wire vclk, vclk_dcm;

// verilator lint_off PINMISSING
DCM_SP #(
    .CLKFX_MULTIPLY (8),
    .CLKFX_DIVIDE   (25),
    .CLK_FEEDBACK   ("NONE")
) dcm_clk (
    .CLKIN  (clk50),
    .CLK0   (),
    .CLK90  (),
    .CLK180 (),
    .CLK270 (),
    .CLKFX  (clk_dcm),
    .RST    (1'b0)
);
BUFG bufg_clk ( .I(clk_dcm), .O(clk) );

DCM_SP #(
    .CLKFX_MULTIPLY (9),
    .CLKFX_DIVIDE   (4),
    .CLK_FEEDBACK   ("NONE")
) dcm_vclk (
    .CLKIN  (clkSocket),
    .CLK0   (),
    .CLK90  (),
    .CLK180 (),
    .CLK270 (),
    .CLKFX  (vclk_dcm),
    .RST    (1'b0)
);
BUFG bufg_vclk ( .I(vclk_dcm), .O(vclk) );
// verilator lint_on PINMISSING

reg [31:0] ctr;
always @(posedge clk)
    ctr <= ctr + 1;

wire [15:0] addr;
wire [15:0] drd, dwr;
wire [1:0] bwe;

wire ce_mem   = addr < 16'h4000;
wire [15:0] drd_mem;
reg old_ce_mem;
always @(posedge clk) old_ce_mem <= ce_mem;

wire ce_vga = (addr >= 16'h8000 && addr < 16'ha000);
// no read back from vga

wire ce_debug = addr >= 16'hff80;
wire [15:0] drd_debug;
reg old_ce_debug;
always @(posedge clk) old_ce_debug <= ce_debug;

wire ce_uart = (addr >= 16'hff00 && addr < 16'hff10);
wire [15:0] drd_uart;
reg old_ce_uart;
always @(posedge clk) old_ce_uart <= ce_uart;

assign drd = (
    old_ce_mem ? drd_mem :
    old_ce_debug ? drd_debug :
    old_ce_uart ? drd_uart :
    16'hffff
);

cozy_memory MEM (
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

vga VGA (
    .vclk       (vclk),
    .rgb        (vgaRgb),
    .hsync      (vgaHsync),
    .vsync      (vgaVsync),

    .mclk       (clk),
    .maddr      (addr[12:1]),
    .min        (dwr),
    .mwe        (ce_vga && bwe[1]),
    .mout       ()
);

uart UART (
    .clk        (clk),
    .addr       (addr),
    .min        (dwr),
    .mout       (drd_uart),
    .bwe        (ce_uart ? bwe : 2'b0),
    .rs232_rx   (rs232_rx),
    .rs232_tx   (rs232_tx)
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
