`default_nettype none

module seven_seg_driver (
    input wire clk,
    input wire cke,
    input wire blank,
    input wire [15:0] value,
    input wire [3:0] dp,
    output wire [7:0] seg,
    output wire [3:0] an
);

reg [1:0] select = 0;
reg [7:0] seg_r = 0;
reg [3:0] an_r = 0;

reg [3:0] nibble;
always @(*) begin
    case (select)
        0: nibble = value[3:0];
        1: nibble = value[7:4];
        2: nibble = value[11:8];
        3: nibble = value[15:12];
    endcase
end

reg [6:0] segs;
always @(*) begin
    case (nibble)
        //
        //     AAA
        //    F   B
        //    F   B
        //     GGG
        //    E   C
        //    E   C
        //     DDD  dp
        //
        //               ABCDEFG
        4'h0: segs = 7'b1111110;
        4'h1: segs = 7'b0110000;
        4'h2: segs = 7'b1101101;
        4'h3: segs = 7'b1111001;
        4'h4: segs = 7'b0110011;
        4'h5: segs = 7'b1011011;
        4'h6: segs = 7'b1011111;
        4'h7: segs = 7'b1110000;
        4'h8: segs = 7'b1111111;
        4'h9: segs = 7'b1111011;
        4'hA: segs = 7'b1110111;
        4'hb: segs = 7'b0011111;
        4'hC: segs = 7'b1001110;
        4'hd: segs = 7'b0111101;
        4'hE: segs = 7'b1001111;
        4'hF: segs = 7'b1000111;
    endcase
end

always @(posedge clk) begin
    if (cke) begin
        if (blank) begin
            an_r    <= 0;
            seg_r   <= 0;
        end else begin
            an_r    <= (1 << select);
            seg_r   <= { segs, dp[select] };
        end
        select      <= select + 1;
    end
end

assign seg  = ~seg_r;
assign an   = ~an_r;

endmodule
