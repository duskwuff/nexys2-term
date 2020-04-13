`default_nettype none

module vga (
    input wire vclk,
    output wire [7:0] rgb,
    output wire hsync,
    output wire vsync,

    input wire mclk,
    input wire [11:0] maddr,
    input wire [15:0] min,
    output wire [15:0] mout,
    input wire mwe
);

// VESA 1280x720@60 (74.25 MHz)
localparam H_PIXELS     = 1280;
localparam H_FP         = 110;
localparam H_SYNC       = 40;
localparam H_BP         = 220;

localparam V_PIXELS     = 720;
localparam V_FP         = 5;
localparam V_SYNC       = 5;
localparam V_BP         = 20;

// Also try: VESA 1366x768@60 RB (72 MHz!)
//localparam H_PIXELS     = 1366;
//localparam H_FP         = 14;
//localparam H_SYNC       = 56;
//localparam H_BP         = 64;
//localparam V_PIXELS     = 768;
//localparam H_FP         = 1;
//localparam V_SYNC       = 3;
//localparam V_BP         = 28;

localparam H_SYNC_START = H_PIXELS + H_FP;
localparam H_SYNC_END   = H_PIXELS + H_FP + H_SYNC;
localparam H_TOTAL      = H_PIXELS + H_FP + H_SYNC + H_BP;

localparam V_SYNC_START = V_PIXELS + V_FP;
localparam V_SYNC_END   = V_PIXELS + V_FP + V_SYNC;
localparam V_TOTAL      = V_PIXELS + V_FP + V_SYNC + V_BP;

// Text resolution / position:
// 112 + 132 x 8 + 112 = 1280
// 96 + 30 x 16 + 144 = 720
// IMPORTANT: These paddings are character-cell-aligned!
localparam PADDING_LEFT = 112;
localparam PADDING_TOP  = 96;
localparam TEXT_COLS    = 132;
localparam TEXT_ROWS    = 30;
// 8x16 cell is hard-coded

localparam HORZ_WINDOW_START    = PADDING_LEFT;
localparam HORZ_WINDOW_END      = PADDING_LEFT + 8 * TEXT_COLS;
localparam VERT_WINDOW_START    = PADDING_TOP;
localparam VERT_WINDOW_END      = PADDING_TOP + 16 * TEXT_ROWS;

`define IN_RANGE(x, lo, hi) ((x) >= (lo) && (x) < (hi))

reg [10:0] horz_ctr = 0;
reg [10:0] vert_ctr = 0;

always @(posedge vclk) begin
    if (horz_ctr + 1 < H_TOTAL) begin
        horz_ctr <= horz_ctr + 'b1;
    end else if (vert_ctr + 1 < V_TOTAL) begin
        horz_ctr <= 0;
        vert_ctr <= vert_ctr + 'b1;
    end else begin
        horz_ctr <= 0;
        vert_ctr <= 0;
    end
end

wire [7:0] rowNumber = (vert_ctr - PADDING_TOP) / 16;

reg [11:0] characterCtr = 0;
always @(posedge vclk) begin
    if (horz_ctr == 0)
        // HACKETY HACK: avoid unnecessarily inferring a multiplier
        // (132 = 128 + 4 which is easy)
        characterCtr <=
            (128 * rowNumber) + (4 * rowNumber) - (PADDING_LEFT / 8);
    else if (horz_ctr % 8 == 0)
        characterCtr <= characterCtr + 1;
end

(* RAM_STYLE="BLOCK" *)
reg [15:0] screen_data [4095:0];

// 15:12 = fg
// 11:8  = bg
// 7:0   = char
reg [15:0] curChar = 0;
always @(posedge vclk) begin
    if ((horz_ctr + 2) % 8 == 0)
        curChar <= screen_data[characterCtr + 1];
end

(* RAM_STYLE="BLOCK" *)
reg [7:0] character_rom [4095:0];
initial begin
    $readmemh("vga_rom.mem", character_rom);
end

reg [7:0] characterBits = 0;
always @(posedge vclk) begin
    if ((horz_ctr + 1) % 8 == 0)
        characterBits <= character_rom[curChar[7:0] * 16 + (vert_ctr % 16)];
end

wire [7:0] fgRgb, bgRgb;
vga_clut clut_fg ( .idx (curChar[15:12]), .rgb (fgRgb) );
vga_clut clut_bg ( .idx (curChar[11:8]),  .rgb (bgRgb) );

// delay colors a clock to keep them in line with character data
reg [7:0] fgRgb2, bgRgb2;
always @(posedge vclk) begin
    fgRgb2  <= fgRgb;
    bgRgb2  <= bgRgb;
end

wire [7:0] bkRgb = 8'b000_000_00;

wire characterBit = characterBits[7 - (horz_ctr % 8)];

wire in_window = 1
    && `IN_RANGE(horz_ctr, HORZ_WINDOW_START, HORZ_WINDOW_END)
    && `IN_RANGE(vert_ctr, VERT_WINDOW_START, VERT_WINDOW_END)
    ;

wire [7:0] outRgb = in_window ? (characterBit ? fgRgb2 : bgRgb2) : bkRgb;

// Register all the outputs for clean output timing

reg [7:0] r_rgb;
reg r_hsync, r_vsync;

always @(posedge vclk) begin
    r_rgb    <= (horz_ctr < H_PIXELS && vert_ctr < V_PIXELS) ? outRgb : 0;
    r_hsync  <= `IN_RANGE(horz_ctr, H_SYNC_START, H_SYNC_END) ? 0 : 1;
    r_vsync  <= `IN_RANGE(vert_ctr, V_SYNC_START, V_SYNC_END) ? 0 : 1;
end

assign rgb   = r_rgb;
assign hsync = r_hsync;
assign vsync = r_vsync;

//////////////////////////////////////////////////////////////////////////////

reg [15:0] r_mout;
always @(posedge mclk) begin
    if (mwe)
        screen_data[maddr] <= min;
    r_mout <= screen_data[maddr];
end

assign mout = r_mout;

endmodule
