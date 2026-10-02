`timescale 1ns / 1ps

//vga_driver
//640x480 at 60 Hz vga timing. gives the pixel to fetch and outputs sync and
//colour
//
//clock:   clk (25.175 MHz pixel clock)
//latency: rgb_in must arrive exactly 1 clk cycle after pixel_x/pixel_y (a
//         registered memory read). sync and colour come out 2 cycles after
//         the counters
//notes:   hsync and vsync are active low. pixel_x and pixel_y are 0 outside
//         the visible area, and the colour outputs are black there

module vga_driver #(
    parameter int CHANNEL_DEPTH = 4,
    parameter int IMG_WIDTH = 640,
    parameter int IMG_HEIGHT = 480,
    parameter int H_FRONT_PORCH = 16,
    parameter int H_SYNC = 96,
    parameter int H_BACK_PORCH = 48,
    parameter int V_FRONT_PORCH = 10,
    parameter int V_SYNC = 2,
    parameter int V_BACK_PORCH = 33
)(
    input logic clk,
    input logic rst,

    input logic [((CHANNEL_DEPTH * 3) - 1):0] rgb_in,
    output logic [($clog2(IMG_WIDTH) - 1):0] pixel_x,
    output logic [($clog2(IMG_HEIGHT) - 1):0] pixel_y,

    output logic hsync,
    output logic vsync,
    output logic [(CHANNEL_DEPTH - 1):0] r,
    output logic [(CHANNEL_DEPTH - 1):0] g,
    output logic [(CHANNEL_DEPTH - 1):0] b
);

    //pixel and line counter logic

    localparam int MAX_PIXEL_COUNT = IMG_WIDTH + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;
    localparam int MAX_LINE_COUNT = IMG_HEIGHT + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;

    logic [($clog2(MAX_PIXEL_COUNT) - 1):0] pixel_count;
    logic [($clog2(MAX_LINE_COUNT) - 1):0] line_count;

    always_ff @(posedge clk) begin
        if (rst) begin
            pixel_count <= '0;
            line_count <= '0;
        end else if (pixel_count != (MAX_PIXEL_COUNT - 1)) begin
            pixel_count <= pixel_count + 1'b1;
        end else begin
            pixel_count <= '0;

            if (line_count != (MAX_LINE_COUNT - 1)) begin
                line_count <= line_count + 1'b1;
            end else begin
                line_count <= '0;
            end
        end
    end

    //pixel coordinate logic

    always_comb begin
        if (pixel_count < IMG_WIDTH) begin
            pixel_x = pixel_count;
        end else begin
            pixel_x = '0;
        end

        if (line_count < IMG_HEIGHT) begin
            pixel_y = line_count;
        end else begin
            pixel_y = '0;
        end
    end

    //vga output logic

    logic next_hsync;
    logic next_vsync;
    logic [(CHANNEL_DEPTH - 1):0] next_r;
    logic [(CHANNEL_DEPTH - 1):0] next_g;
    logic [(CHANNEL_DEPTH - 1):0] next_b;

    //rgb_in arrives one cycle after pixel_x/pixel_y because the frame
    //buffer read is registered, so sync and blanking are delayed one cycle to
    //line up with it

    logic next_hsync_d;
    logic next_vsync_d;
    logic active_d;

    always_ff @(posedge clk) begin
        if (rst) begin
            next_hsync_d <= 1'b1;
            next_vsync_d <= 1'b1;
            active_d <= '0;
        end else begin
            next_hsync_d <= next_hsync;
            next_vsync_d <= next_vsync;
            active_d <= (pixel_count < IMG_WIDTH) && (line_count < IMG_HEIGHT);
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
            r <= '0;
            g <= '0;
            b <= '0;
        end else begin
            hsync <= next_hsync_d;
            vsync <= next_vsync_d;
            r <= next_r;
            g <= next_g;
            b <= next_b;
        end
    end

    always_comb begin
        if ((pixel_count < (IMG_WIDTH + H_FRONT_PORCH)) || (pixel_count >= (IMG_WIDTH + H_FRONT_PORCH + H_SYNC))) begin
            next_hsync = 1'b1;
        end else begin
            next_hsync = '0;
        end

        if ((line_count < (IMG_HEIGHT + V_FRONT_PORCH)) || (line_count >= (IMG_HEIGHT + V_FRONT_PORCH + V_SYNC))) begin
            next_vsync = 1'b1;
        end else begin
            next_vsync = '0;
        end
    end

    always_comb begin
        if (active_d) begin
            next_r = rgb_in[((CHANNEL_DEPTH * 3) - 1):(CHANNEL_DEPTH * 2)];
            next_g = rgb_in[((CHANNEL_DEPTH * 2) - 1):CHANNEL_DEPTH];
            next_b = rgb_in[(CHANNEL_DEPTH - 1):0];
        end else begin
            next_r = '0;
            next_g = '0;
            next_b = '0;
        end
    end
endmodule
