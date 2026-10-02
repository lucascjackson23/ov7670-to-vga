`timescale 1ns / 1ps

//ov7670_driver
//everything needed to run the camera: xclk generation, register init over
//sccb, and pixel capture
//
//clock:   clk (100 MHz). xclk (24 MHz, clk_wiz_0) is generated here and
//         forwarded to the camera through an ODDR
//latency: see ov7670_capture. no pixels come out until init_done is high
//assumes: sio_d has a pull-up (set in the xdc)
//notes:   capture is held in reset until init is done, so no pixels are
//         produced while the camera is still being configured

module ov7670_driver #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int IMG_WIDTH = 320,
    parameter int IMG_HEIGHT = 240
)(
    input logic clk,
    input logic rst,

    input logic pclk,
    input logic vsync,
    input logic href,
    input logic [7:0] data,

    output logic xclk,
    output logic ov7670_rst_n,
    output logic pwdn,

    output logic sio_c,
    inout  wire  sio_d,

    output logic init_done,

    output logic [15:0] pixel,
    output logic pixel_valid,
    output logic [($clog2(IMG_WIDTH) - 1):0] pixel_x,
    output logic [($clog2(IMG_HEIGHT) - 1):0] pixel_y
);

    //clocking

    logic locked;
    logic rst_sync_0;
    logic rst_sync_1;
    logic sys_rst;
    logic xclk_int;

    clk_wiz_0 clk_wiz_inst (
        .clk_in1  (clk),
        .clk_out1 (xclk_int),
        .locked   (locked),
        .reset    (rst)
    );

    ODDR #(
        .DDR_CLK_EDGE ("OPPOSITE_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    ) xclk_oddr_inst (
        .Q  (xclk),
        .C  (xclk_int),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );

    //reset sync

    always_ff @(posedge clk) begin
        if (rst || !locked) begin
            rst_sync_0 <= 1'b1;
            rst_sync_1 <= 1'b1;
        end else begin
            rst_sync_0 <= '0;
            rst_sync_1 <= rst_sync_0;
        end
    end

    assign sys_rst = rst_sync_1;

    //camera power pins

    assign pwdn = '0;

    //sccb

    logic [7:0] id_addr;
    logic [7:0] reg_addr;
    logic [7:0] reg_data;
    logic start_write;
    logic busy;
    logic sio_d_oe;

    assign sio_d = sio_d_oe ? 1'b0 : 1'bz;

    ov7670_init_sequencer #(
        .CLK_FREQ (CLK_FREQ)
    ) init_sequencer_inst (
        .clk            (clk),
        .rst            (sys_rst),
        .id_addr        (id_addr),
        .reg_addr       (reg_addr),
        .reg_data       (reg_data),
        .start_write    (start_write),
        .busy           (busy),
        .ov7670_reset_n (ov7670_reset_n),
        .done           (init_done)
    );

    sccb_master #(
        .CLK_FREQ (CLK_FREQ)
    ) sccb_master_inst (
        .clk         (clk),
        .rst         (sys_rst),
        .start_write (start_write),
        .id_addr     (id_addr),
        .reg_addr    (reg_addr),
        .reg_data    (reg_data),
        .sio_c       (sio_c),
        .sio_d_oe    (sio_d_oe),
        .busy        (busy)
    );

    //pixel capture

    logic capture_rst;

    assign capture_rst = sys_rst || !init_done;

    ov7670_capture #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT)
    ) capture_inst (
        .clk         (clk),
        .rst         (capture_rst),
        .pclk        (pclk),
        .vsync       (vsync),
        .href        (href),
        .data        (data),
        .pixel       (pixel),
        .pixel_valid (pixel_valid),
        .pixel_x     (pixel_x),
        .pixel_y     (pixel_y)
    );
endmodule
