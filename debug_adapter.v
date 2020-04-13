`default_nettype none

module debug_adapter (
    input wire clk,
    input wire [15:0] addr,
    input wire [1:0] bwe,
    input wire [15:0] din,
    output reg [15:0] dout,

    input wire [7:0] sw,
    input wire [3:0] btn,
    output reg [7:0] led,
    output reg [15:0] ssd
);

reg [7:0] ledr;

always @(posedge clk) begin
    if (bwe[0])
        case (addr[3:0])
            4'h0: led <= din[7:0];
            4'h2: ssd <= din[15:0];
            default: /* nothing */;
        endcase

    case (addr[3:0])
        4'h4: dout <= {8'b0, sw};
        4'h6: dout <= {12'b0, btn};
        default: dout <= 16'b0;
    endcase
end

endmodule
