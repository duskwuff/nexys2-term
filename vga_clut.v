`default_nettype none

module vga_clut (
    input wire [3:0] idx,
    output reg [7:0] rgb
);

always @(*) begin
    case (idx)
        //              RRR GGG BB
        4'h0: rgb = 8'b000_000_00; // black
        4'h1: rgb = 8'b101_000_00; // red
        4'h2: rgb = 8'b000_101_00; // green
        4'h3: rgb = 8'b111_111_00; // yellow
        4'h4: rgb = 8'b000_000_11; // blue
        4'h5: rgb = 8'b101_000_10; // magenta
        4'h6: rgb = 8'b000_101_10; // cyan
        4'h7: rgb = 8'b111_111_11; // white
        4'h8: rgb = 8'b010_010_01; // gray
        4'h9: rgb = 8'b111_000_00; // br red
        4'ha: rgb = 8'b000_111_00; // br green
        4'hb: rgb = 8'b111_111_01; // br yellow
        4'hc: rgb = 8'b011_011_11; // br blue
        4'hd: rgb = 8'b111_000_11; // br magenta
        4'he: rgb = 8'b010_111_11; // br cyan
        4'hf: rgb = 8'b111_111_11; // white again
    endcase
end

endmodule
