`default_nettype none

module uart_impl #(
    parameter DIVIDER = 1
) (
    input wire clk,

    input wire rx,
    output wire tx,

    input wire [7:0] txdata,
    input wire txstrobe,
    output wire txready,

    output wire [7:0] rxdata,
    output wire rxstrobe
);

// Speed up the receiver slightly if the divider isn't too low
localparam TX_DIVIDER = DIVIDER;
localparam RX_DIVIDER = DIVIDER < 20 ? DIVIDER : DIVIDER-1;

// Adjust the sample point to account for fast-receiver drift
localparam RX_SAMPLE = (DIVIDER >= 20 && DIVIDER < 100) ? DIVIDER/3 : DIVIDER/2;

//////////////////////////////////////////////////////////////////////////////

reg [7:0] tx_bit_counter = 0;
reg [3:0] tx_word_counter = 0;
// 10 = start bit
//  9 = LSB
//   ...
//  2 = MSB
//  1 = stop bit
//  0 = idle

// txbuf doesn't contain the stop bit because it's equal to the idle state
// which gets shifted in at each step!
reg [8:0] txbuf = ~0;

always @(posedge clk) begin
    if (tx_word_counter > 0) begin
        if (tx_bit_counter == 0) begin
            tx_bit_counter <= TX_DIVIDER-1;
            tx_word_counter <= tx_word_counter - 1;
            txbuf <= { 1'b1, txbuf[8:1] };
        end else begin
            tx_bit_counter <= tx_bit_counter - 1;
        end
    end else if (txstrobe) begin
        tx_bit_counter  <= TX_DIVIDER-1;
        tx_word_counter <= 10;
        txbuf <= { txdata, 1'b0 };
    end
end

assign tx = txbuf[0];
assign txready = (tx_word_counter == 0);

//////////////////////////////////////////////////////////////////////////////

reg [7:0] rx_bit_counter = 0;
reg [3:0] rx_word_counter = 0;
reg [7:0] rxbuf = 0;
reg rxstrobe_r = 0;

always @(posedge clk) begin
    if (rx_word_counter > 0) begin
        if (rx_bit_counter == 0) begin
            rx_bit_counter <= RX_DIVIDER-1;
            rx_word_counter <= rx_word_counter - 1;
        end else begin
            rx_bit_counter <= rx_bit_counter - 1;
        end
        if (rx_bit_counter == RX_SAMPLE && rx_word_counter >= 2 && rx_word_counter <= 9) begin
            rxbuf <= { rx, rxbuf[7:1] };
        end
    end else if (rx == 0) begin
        rx_bit_counter  <= RX_DIVIDER-1;
        rx_word_counter <= 10;
    end
    rxstrobe_r <= (rx_word_counter == 1 && rx_bit_counter == 0);
end

assign rxdata = rxbuf;
assign rxstrobe = rxstrobe_r;

endmodule
