`default_nettype none

module cozy_memory (
    input wire clk,
    input wire [15:0] addr,
    input wire [15:0] din,
    input wire [1:0] bwe,
    output wire [15:0] dout
);

parameter BITS = 8;
localparam DEPTH = 2**BITS;

parameter INIT_HI = "";
parameter INIT_LO = "";

(* RAM_STYLE="BLOCK" *)
reg [7:0] ram_hi [DEPTH/2-1:0];

(* RAM_STYLE="BLOCK" *)
reg [7:0] ram_lo [DEPTH/2-1:0];

initial begin
    if (INIT_LO)
        $readmemh(INIT_LO, ram_lo);
    if (INIT_HI)
        $readmemh(INIT_HI, ram_hi);
end

wire [BITS-2:0] waddr = addr[BITS-1:1];

reg latched_addr_0;

reg whi, wlo;
reg [7:0] din_hi, din_lo;
reg [7:0] dout_hi, dout_lo;

always @(*) begin
    if (bwe == 2'b01 && addr[0] == 0) begin
        whi = 0; din_hi = 0;
        wlo = 1; din_lo = din[7:0];
    end else if (bwe == 2'b01 && addr[0] == 1) begin
        whi = 1; din_hi = din[7:0];
        wlo = 0; din_lo = 0;
    end else if (bwe == 2'b11) begin
        whi = 1; din_hi = din[15:8];
        wlo = 1; din_lo = din[7:0];
    end else begin
        whi = 0; din_hi = 0;
        wlo = 0; din_lo = 0;
    end
end

always @(posedge clk) begin
    if (whi) ram_hi[waddr] <= din_hi;
    dout_hi <= ram_hi[waddr];

    if (wlo) ram_lo[waddr] <= din_lo;
    dout_lo <= ram_lo[waddr];

    latched_addr_0 <= addr[0];
end

assign dout = latched_addr_0 ? { 8'b0, dout_hi } : { dout_hi, dout_lo };

endmodule
