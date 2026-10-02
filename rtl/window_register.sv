`timescale 1ns / 1ps

//window_register
//shift register giving the last NUM_TAPS pixels of one row of the window
//
//clock:   clk, advances only on pixel_valid
//latency: taps[0] is the newest pixel, taps[NUM_TAPS - 1] the oldest

module window_register #(
    parameter int NUM_TAPS   = 3,
    parameter int DATA_WIDTH = 12
)(
    input logic clk,
    input logic rst,
    input logic pixel_valid,

    input  logic [(DATA_WIDTH - 1):0] data_in,
    output logic [(DATA_WIDTH - 1):0] taps [(NUM_TAPS - 1):0]
);

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_TAPS; i++) begin
                taps[i] <= '0;
            end
        end else if (pixel_valid) begin
            taps[0] <= data_in;

            for (int i = 1; i < NUM_TAPS; i++) begin
                taps[i] <= taps[i - 1];
            end
        end
    end
endmodule
