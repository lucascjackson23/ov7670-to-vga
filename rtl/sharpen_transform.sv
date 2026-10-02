`timescale 1ns / 1ps

//sharpen_transform
//3x3 sharpen on each channel (5 in the centre, -1 on the four neighbours),
//clamped to 0 to MAX_VALUE
//
//clock:   none, combinational
//latency: 0
//assumes: taps[0:8] ordered as built in image_transform. the kernel is
//         symmetric, so the order does not change the result

module sharpen_transform #(
    parameter int CHANNEL_DEPTH = 4
)(
    input  logic [((CHANNEL_DEPTH * 3) - 1):0] taps [0:8],
    output logic [((CHANNEL_DEPTH * 3) - 1):0] pixel_out
);

    localparam int NUM_TAPS = 9;
    localparam int MAX_VALUE = (2 ** CHANNEL_DEPTH) - 1;

    localparam int SUM_WIDTH = CHANNEL_DEPTH + 4;

    localparam int KERNEL [0:8] = 
    '{ 0, -1,  0,
      -1,  5, -1,
       0, -1,  0};

    logic signed [(SUM_WIDTH - 1):0] r_sum;
    logic signed [(SUM_WIDTH - 1):0] g_sum;
    logic signed [(SUM_WIDTH - 1):0] b_sum;

    function automatic logic [(CHANNEL_DEPTH - 1):0] clamp
        (input logic signed [(SUM_WIDTH - 1):0] value);

        if (value < 0) begin
            return '0;
        end else if (value > MAX_VALUE) begin
            return MAX_VALUE[(CHANNEL_DEPTH - 1):0];
        end else begin
            return value[(CHANNEL_DEPTH - 1):0];
        end
    endfunction

    always_comb begin
        r_sum = '0;
        g_sum = '0;
        b_sum = '0;

        for (int i = 0; i < NUM_TAPS; i++) begin
            r_sum = r_sum + ($signed({1'b0, taps[i][((CHANNEL_DEPTH * 3) - 1):(CHANNEL_DEPTH * 2)]}) * KERNEL[i]);
            g_sum = g_sum + ($signed({1'b0, taps[i][((CHANNEL_DEPTH * 2) - 1):CHANNEL_DEPTH]}) * KERNEL[i]);
            b_sum = b_sum + ($signed({1'b0, taps[i][(CHANNEL_DEPTH - 1):0]}) * KERNEL[i]);
        end
    end

    logic [(CHANNEL_DEPTH - 1):0] r_sharp;
    logic [(CHANNEL_DEPTH - 1):0] g_sharp;
    logic [(CHANNEL_DEPTH - 1):0] b_sharp;

    assign r_sharp = clamp(r_sum);
    assign g_sharp = clamp(g_sum);
    assign b_sharp = clamp(b_sum);

    assign pixel_out = {r_sharp, g_sharp, b_sharp};
endmodule
