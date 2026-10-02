`timescale 1ns / 1ps

//grayscale_transform
//approximate luminance, gray = (r + 2g + b) / 4, copied to all three channels
//
//clock:   none, combinational
//latency: 0

module grayscale_transform #(
    parameter int CHANNEL_DEPTH = 4
)(
    input  logic [((CHANNEL_DEPTH * 3) - 1):0] pixel_in,
    output logic [((CHANNEL_DEPTH * 3) - 1):0] pixel_out
);
    logic [((CHANNEL_DEPTH) - 1):0] r;
    logic [((CHANNEL_DEPTH) - 1):0] g;
    logic [((CHANNEL_DEPTH) - 1):0] b;
    
    assign r = pixel_in[((CHANNEL_DEPTH * 3) - 1):(CHANNEL_DEPTH * 2)];
    assign g = pixel_in[((CHANNEL_DEPTH * 2) - 1):(CHANNEL_DEPTH)];
    assign b = pixel_in[(CHANNEL_DEPTH - 1):0];
    
    logic [(CHANNEL_DEPTH + 1):0] gray_sum;
    logic [(CHANNEL_DEPTH - 1):0] gray;

    assign gray_sum = r + (g << 1) + b;
    assign gray = gray_sum >> 2;
    
    assign pixel_out = {gray, gray, gray};
endmodule
