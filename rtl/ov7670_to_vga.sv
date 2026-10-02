`timescale 1ns / 1ps

//ov7670_to_vga
//top level. captures 320x240 rgb565 video from an ov7670, runs it through a
//selectable 3x3 filter and shows it on a 640x480 vga display
//
//clock:   clk (100 MHz) for the camera, filters and frame buffer writes.
//         vga_pclk (25.175 MHz, clk_wiz_1) for the display and frame buffer
//         reads. the frame buffer is the only crossing between the two
//latency: a camera pixel reaches the frame buffer about one line after it is
//         captured (the 3x3 window needs the line below it)
//assumes: transform_sel comes from slide switches and is async, so it is
//         synchronised here
//notes:   the frame buffer is single buffered, so tearing is visible. a
//         second buffer would not fit in block ram. each source pixel is
//         shown as a 2x2 block to fill the screen

module ov7670_to_vga #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int SRC_WIDTH = 320,
    parameter int SRC_HEIGHT = 240,
    parameter int CHANNEL_DEPTH = 4
)(
    input logic clk,
    input logic rst,

    input logic [2:0] transform_sel,

    input  logic ov7670_pclk,
    input  logic ov7670_vsync,
    input  logic ov7670_href,
    input  logic [7:0] ov7670_data,

    output logic ov7670_xclk,
    output logic ov7670_reset_n,
    output logic ov7670_pwdn,

    output logic ov7670_sio_c,
    inout  wire  ov7670_sio_d,

    output logic ov7670_init_done,

    output logic vga_hsync,
    output logic vga_vsync,
    output logic [(CHANNEL_DEPTH - 1):0] vga_r,
    output logic [(CHANNEL_DEPTH - 1):0] vga_g,
    output logic [(CHANNEL_DEPTH - 1):0] vga_b
);

    localparam int NUM_PIXELS  = SRC_WIDTH * SRC_HEIGHT;
    localparam int ADDR_WIDTH  = $clog2(NUM_PIXELS);
    localparam int PIXEL_WIDTH = CHANNEL_DEPTH * 3;

    //vga pixel clock logic

    logic vga_pclk;
    logic vga_pclk_locked;
    logic rst_vga_pclk_sync_0;
    logic rst_vga_pclk_sync_1;

    clk_wiz_1 clk_wiz_1_inst (
        .clk_in1  (clk),
        .clk_out1 (vga_pclk),
        .locked   (vga_pclk_locked),
        .reset    (rst)
    );

    always_ff @(posedge vga_pclk) begin
        if (rst || !vga_pclk_locked) begin
            rst_vga_pclk_sync_0 <= 1'b1;
            rst_vga_pclk_sync_1 <= 1'b1;
        end else begin
            rst_vga_pclk_sync_0 <= '0;
            rst_vga_pclk_sync_1 <= rst_vga_pclk_sync_0;
        end
    end

    //transform select sync
    //comes from a slide switch, so it is asynchronous to clk

    logic [2:0] transform_sel_sync_0;
    logic [2:0] transform_sel_sync_1;

    always_ff @(posedge clk) begin
        transform_sel_sync_0 <= transform_sel;
        transform_sel_sync_1 <= transform_sel_sync_0;
    end

    //ov7670 logic

    logic [15:0] ov7670_pixel;
    logic ov7670_pixel_valid;
    logic [($clog2(SRC_WIDTH) - 1):0]  ov7670_pixel_x;
    logic [($clog2(SRC_HEIGHT) - 1):0] ov7670_pixel_y;

    ov7670_driver #(
        .CLK_FREQ   (CLK_FREQ),
        .IMG_WIDTH  (SRC_WIDTH),
        .IMG_HEIGHT (SRC_HEIGHT)
    ) ov7670_driver_inst (
        .clk          (clk),
        .rst          (rst),
        .pclk         (ov7670_pclk),
        .vsync        (ov7670_vsync),
        .href         (ov7670_href),
        .data         (ov7670_data),
        .xclk         (ov7670_xclk),
        .ov7670_rst_n (ov7670_reset_n),
        .pwdn         (ov7670_pwdn),
        .sio_c        (ov7670_sio_c),
        .sio_d        (ov7670_sio_d),
        .init_done    (ov7670_init_done),
        .pixel        (ov7670_pixel),
        .pixel_valid  (ov7670_pixel_valid),
        .pixel_x      (ov7670_pixel_x),
        .pixel_y      (ov7670_pixel_y)
    );

    //rgb565 to CHANNEL_DEPTH bits per channel
    //done before the transform so the pipeline and the frame buffer both
    //work on evenly sized channels

    logic [(PIXEL_WIDTH - 1):0] transform_pixel_in;

    assign transform_pixel_in = {ov7670_pixel[15:12], ov7670_pixel[10:7], ov7670_pixel[4:1]};

    //image transform logic

    logic [(PIXEL_WIDTH - 1):0] transform_pixel_out;
    logic transform_pixel_out_valid;
    logic [($clog2(SRC_WIDTH) - 1):0]  transform_pixel_x;
    logic [($clog2(SRC_HEIGHT) - 1):0] transform_pixel_y;

    image_transform #(
        .IMG_WIDTH     (SRC_WIDTH),
        .IMG_HEIGHT    (SRC_HEIGHT),
        .CHANNEL_DEPTH (CHANNEL_DEPTH)
    ) image_transform_inst (
        .clk             (clk),
        .rst             (rst),
        .pixel_valid     (ov7670_pixel_valid),
        .transform_sel   (transform_sel_sync_1),
        .pixel_in        (transform_pixel_in),
        .pixel_x_in      (ov7670_pixel_x),
        .pixel_y_in      (ov7670_pixel_y),
        .pixel_out       (transform_pixel_out),
        .pixel_x_out     (transform_pixel_x),
        .pixel_y_out     (transform_pixel_y),
        .pixel_out_valid (transform_pixel_out_valid)
    );

    //vga logic

    logic [($clog2(640) - 1):0] vga_pixel_x;
    logic [($clog2(480) - 1):0] vga_pixel_y;
    logic [(PIXEL_WIDTH - 1):0] vga_rgb;

    vga_driver #(
        .CHANNEL_DEPTH (CHANNEL_DEPTH)
    ) vga_driver_inst (
        .clk     (vga_pclk),
        .rst     (rst_vga_pclk_sync_1),
        .rgb_in  (vga_rgb),
        .pixel_x (vga_pixel_x),
        .pixel_y (vga_pixel_y),
        .hsync   (vga_hsync),
        .vsync   (vga_vsync),
        .r       (vga_r),
        .g       (vga_g),
        .b       (vga_b)
    );

    //pipeline register between the transform and the frame buffer,
    //so the filter logic and the frame buffer write each get their own clock
    //cycle. pixel, coordinates and valid are all delayed together

    logic [(PIXEL_WIDTH - 1):0] transform_pixel_out_d;
    logic transform_pixel_out_valid_d;
    logic [($clog2(SRC_WIDTH) - 1):0]  transform_pixel_x_d;
    logic [($clog2(SRC_HEIGHT) - 1):0] transform_pixel_y_d;

    always_ff @(posedge clk) begin
        if (rst) begin
            transform_pixel_out_valid_d <= '0;
        end else begin
            transform_pixel_out_valid_d <= transform_pixel_out_valid;
        end

        transform_pixel_out_d <= transform_pixel_out;
        transform_pixel_x_d   <= transform_pixel_x;
        transform_pixel_y_d   <= transform_pixel_y;
    end

    //frame buffer addr logic
    //the vga side reads each source pixel twice across and twice down, so
    //320x240 fills the 640x480 screen

    logic [(ADDR_WIDTH - 1):0] frame_buffer_wr_addr;
    logic [(ADDR_WIDTH - 1):0] frame_buffer_rd_addr;

    assign frame_buffer_wr_addr = (transform_pixel_y_d * SRC_WIDTH) + transform_pixel_x_d;
    assign frame_buffer_rd_addr = ((vga_pixel_y >> 1) * SRC_WIDTH) + (vga_pixel_x >> 1);

    //frame buffer
    //single buffered, so the display can read rows the camera is still
    //writing. that shows up as tearing, which is accepted here because a
    //second buffer would not fit in block ram

    logic [(PIXEL_WIDTH - 1):0] frame_buffer [0:(NUM_PIXELS - 1)];

    always_ff @(posedge clk) begin
        if (transform_pixel_out_valid_d) begin
            frame_buffer[frame_buffer_wr_addr] <= transform_pixel_out_d;
        end
    end

    always_ff @(posedge vga_pclk) begin
        vga_rgb <= frame_buffer[frame_buffer_rd_addr];
    end
endmodule
