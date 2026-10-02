`timescale 1ns / 1ps

//sobel_transform
//sobel edge magnitude on the luminance of the 3x3 window, shown as gray
//
//clock:   clk (100 MHz)
//latency: 1 clk cycle (the gradients are registered so the design meets
//         timing at 100 MHz)
//assumes: taps[0:8] ordered as built in image_transform. |gx| + |gy| does not
//         depend on the window being flipped, so the order does not matter
//notes:   uses |gx| + |gy| instead of sqrt(gx^2 + gy^2), scaled down by
//         EDGE_SHIFT and saturated

module sobel_transform #(
    parameter int CHANNEL_DEPTH = 4,
    parameter int EDGE_SHIFT = 2
)(
    input  logic clk,
    input  logic [((CHANNEL_DEPTH * 3) - 1):0] taps [0:8],
    output logic [((CHANNEL_DEPTH * 3) - 1):0] pixel_out
);

    localparam int NUM_TAPS  = 9;
    localparam int MAX_VALUE = (2 ** CHANNEL_DEPTH) - 1;

    localparam int SUM_WIDTH = CHANNEL_DEPTH + 4;

    localparam int KERNEL_X [0:8] = '{-1,  0,  1,
                                      -2,  0,  2,
                                      -1,  0,  1};

    localparam int KERNEL_Y [0:8] = '{-1, -2, -1,
                                       0,  0,  0,
                                       1,  2,  1};

    function automatic logic [(CHANNEL_DEPTH - 1):0] gray_of
        (input logic [((CHANNEL_DEPTH * 3) - 1):0] pixel);

        logic [(CHANNEL_DEPTH - 1):0] r;
        logic [(CHANNEL_DEPTH - 1):0] g;
        logic [(CHANNEL_DEPTH - 1):0] b;
        logic [(CHANNEL_DEPTH + 1):0] sum;

        r = pixel[((CHANNEL_DEPTH * 3) - 1):(CHANNEL_DEPTH * 2)];
        g = pixel[((CHANNEL_DEPTH * 2) - 1):CHANNEL_DEPTH];
        b = pixel[(CHANNEL_DEPTH - 1):0];

        sum = r + (g << 1) + b;
        return sum >> 2;
    endfunction

    function automatic logic [(SUM_WIDTH - 1):0] abs_of
        (input logic signed [(SUM_WIDTH - 1):0] value);

        if (value < 0) begin
            return -value;
        end else begin
            return value;
        end
    endfunction

    logic signed [(SUM_WIDTH - 1):0] gx;
    logic signed [(SUM_WIDTH - 1):0] gy;
    logic [(SUM_WIDTH - 1):0] magnitude;
    logic [(SUM_WIDTH - 1):0] scaled;

    always_comb begin
        gx = '0;
        gy = '0;

        for (int i = 0; i < NUM_TAPS; i++) begin
            gx = gx + ($signed({1'b0, gray_of(taps[i])}) * KERNEL_X[i]);
            gy = gy + ($signed({1'b0, gray_of(taps[i])}) * KERNEL_Y[i]);
        end
    end

    logic signed [(SUM_WIDTH - 1):0] gx_d;
    logic signed [(SUM_WIDTH - 1):0] gy_d;

    always_ff @(posedge clk) begin
        gx_d <= gx;
        gy_d <= gy;
    end

    always_comb begin
        magnitude = abs_of(gx_d) + abs_of(gy_d);
        scaled    = magnitude >> EDGE_SHIFT;
    end

    logic [(CHANNEL_DEPTH - 1):0] edge_value;

    assign edge_value = (scaled > MAX_VALUE) ? MAX_VALUE[(CHANNEL_DEPTH - 1):0]
                                             : scaled[(CHANNEL_DEPTH - 1):0];

    assign pixel_out = {edge_value, edge_value, edge_value};
endmodule
