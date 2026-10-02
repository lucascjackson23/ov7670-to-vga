`timescale 1ns / 1ps

//ov7670_capture
//turns the camera's byte stream into rgb565 pixels with x/y coordinates
//
//clock:   clk (100 MHz). pclk, href and vsync are oversampled through 2 flop
//         synchronisers and edge detected. pclk is not used as a clock
//latency: pixel_valid pulses about 3 clk cycles after the pclk edge of each
//         pixel's second byte
//assumes: pclk is slow enough (12 MHz here) for data to still be stable when
//         it is sampled, 2 to 3 clk cycles after the synchronised pclk edge.
//         data is not synchronised, so a much faster pclk would break this
//notes:   waits for a vsync after reset so the first frame starts at row 0.
//         pixels outside IMG_WIDTH x IMG_HEIGHT are dropped

module ov7670_capture #(
    parameter int IMG_WIDTH  = 320,
    parameter int IMG_HEIGHT = 240
)(
    input logic rst,
    input logic clk,

    input  logic pclk,
    input  logic vsync,
    input  logic href,
    input  logic [7:0] data,

    output logic [15:0] pixel,
    output logic pixel_valid,
    output logic [($clog2(IMG_WIDTH) - 1):0]  pixel_x,
    output logic [($clog2(IMG_HEIGHT) - 1):0] pixel_y
);

    //pclk tick logic

    logic pclk_sync_0;
    logic pclk_sync_1;
    logic last_pclk_sync_1;
    logic pclk_tick;

    assign pclk_tick = pclk_sync_1 && !last_pclk_sync_1;

    always_ff @(posedge clk) begin
        pclk_sync_0 <= pclk;
        pclk_sync_1 <= pclk_sync_0;
        last_pclk_sync_1 <= pclk_sync_1;
    end

    //href tick logic

    logic href_sync_0;
    logic href_sync_1;
    logic last_href_sync_1;
    logic negedge_href_tick;

    assign negedge_href_tick = !href_sync_1 && last_href_sync_1;

    always_ff @(posedge clk) begin
        href_sync_0 <= href;
        href_sync_1 <= href_sync_0;
        last_href_sync_1 <= href_sync_1;
    end

    //vsync tick logic

    logic vsync_sync_0;
    logic vsync_sync_1;
    logic last_vsync_sync_1;
    logic posedge_vsync_tick;

    assign posedge_vsync_tick = vsync_sync_1 && !last_vsync_sync_1;

    always_ff @(posedge clk) begin
        vsync_sync_0 <= vsync;
        vsync_sync_1 <= vsync_sync_0;
        last_vsync_sync_1 <= vsync_sync_1;
    end

    //pixel output logic

    logic waiting_for_vsync;
    logic capture;
    logic upper_pixel_byte;
    logic [($clog2(IMG_WIDTH) - 1):0]  next_pixel_x;
    logic [($clog2(IMG_HEIGHT) - 1):0] next_pixel_y;

    assign capture = pclk_tick && !waiting_for_vsync && href_sync_1;

    always_ff @(posedge clk) begin
        if (rst) begin
            waiting_for_vsync <= 1'b1;
        end else if (posedge_vsync_tick) begin
            waiting_for_vsync <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst || negedge_href_tick) begin
            upper_pixel_byte <= 1'b1;
        end else if (capture) begin
            upper_pixel_byte <= !upper_pixel_byte;
        end
    end

    always_ff @(posedge clk) begin
        if (rst || posedge_vsync_tick) begin
            pixel_valid  <= '0;
            pixel <= '0;
            pixel_x <= '0;
            pixel_y <= '0;
            next_pixel_x <= '0;
            next_pixel_y <= '0;
        end else if (negedge_href_tick && !waiting_for_vsync) begin
            pixel_valid <= '0;
            next_pixel_x <= '0;
            
            if (next_pixel_y < IMG_HEIGHT) begin
                next_pixel_y <= next_pixel_y + 1'b1;
            end
        end else if (capture) begin
            if (upper_pixel_byte) begin
                pixel_valid <= '0;
                pixel[15:8] <= data;
            end else begin
                pixel_valid  <= (next_pixel_x < IMG_WIDTH) && (next_pixel_y < IMG_HEIGHT);
                pixel[7:0]   <= data;
                pixel_x <= next_pixel_x;
                pixel_y <= next_pixel_y;

                if (next_pixel_x < IMG_WIDTH) begin
                    next_pixel_x <= next_pixel_x + 1'b1;
                end
            end
        end else begin
            pixel_valid <= '0;
        end
    end
endmodule
