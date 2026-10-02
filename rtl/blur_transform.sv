`timescale 1ns / 1ps

//blur_transform
//3x3 gaussian blur on each channel
//
//clock:   none, combinational
//latency: 0
//assumes: taps[0:8] ordered as built in image_transform (row_0 is the newest
//         line). the kernel is symmetric, so the order does not change the result

module blur_transform #(
    parameter int CHANNEL_DEPTH = 4
)(
    input  logic [((CHANNEL_DEPTH * 3) - 1):0] taps [0:8],
    output logic [((CHANNEL_DEPTH * 3) - 1):0] pixel_out
);
    localparam int NUM_TAPS = 9;
    localparam int SUM_WIDTH = CHANNEL_DEPTH + 4;

    //gaussian 3x3, weights sum to 16 so the divide is a shift by 4

    localparam int KERNEL [0:(NUM_TAPS - 1)] = 
    '{1, 2, 1,
      2, 4, 2,
      1, 2, 1};

    logic [(SUM_WIDTH - 1):0] r_sum;
    logic [(SUM_WIDTH - 1):0] g_sum;
    logic [(SUM_WIDTH - 1):0] b_sum;

    always_comb begin
        r_sum = '0;
        g_sum = '0;
        b_sum = '0;

        for (int i = 0; i < NUM_TAPS; i++) begin
            r_sum = r_sum + (taps[i][((CHANNEL_DEPTH * 3) - 1):(CHANNEL_DEPTH * 2)] * KERNEL[i]);
            g_sum = g_sum + (taps[i][((CHANNEL_DEPTH * 2) - 1):CHANNEL_DEPTH]       * KERNEL[i]);
            b_sum = b_sum + (taps[i][(CHANNEL_DEPTH - 1):0]                         * KERNEL[i]);
        end
    end

    logic [(CHANNEL_DEPTH - 1):0] r_blur;
    logic [(CHANNEL_DEPTH - 1):0] g_blur;
    logic [(CHANNEL_DEPTH - 1):0] b_blur;

    assign r_blur = r_sum >> 4;
    assign g_blur = g_sum >> 4;
    assign b_blur = b_sum >> 4;

    assign pixel_out = {r_blur, g_blur, b_blur};
endmodule
