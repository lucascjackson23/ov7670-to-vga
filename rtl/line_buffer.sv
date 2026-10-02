`timescale 1ns / 1ps

//line_buffer
//delays a pixel stream by exactly one line. each write returns the value
//stored at the same x on the previous line
//
//clock:   clk, advances only on pixel_valid
//latency: one line (data_out is the previous line's value at addr)
//assumes: addr is the pixel's x coordinate and is below WIDTH
//notes:   addressed by x instead of a free running counter, so a dropped or
//         extra pixel cannot shift later lines out of alignment

module line_buffer #(
    parameter int WIDTH = 320,
    parameter int DATA_WIDTH = 12
)(
    input logic clk,
    input logic rst,
    input logic pixel_valid,

    input  logic [($clog2(WIDTH) - 1):0] addr,

    input  logic [(DATA_WIDTH - 1):0] data_in,
    output logic [(DATA_WIDTH - 1):0] data_out
);

    logic [(DATA_WIDTH - 1):0] mem [0:(WIDTH - 1)];

    always_ff @(posedge clk) begin
        if (rst) begin
            data_out <= '0;
        end else if (pixel_valid) begin
            data_out <= mem[addr];
            mem[addr] <= data_in;
        end
    end
endmodule
