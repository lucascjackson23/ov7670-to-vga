`timescale 1ns / 1ps

//image_transform
//3x3 sliding window over the pixel stream, feeding grayscale, blur, sharpen
//and sobel filters, selected by transform_sel
//
//clock:   clk (100 MHz), the window advances only on pixel_valid
//latency: pixel_out is the window centre, IMG_WIDTH + 2 valid pixels behind
//         pixel_in. pixel_out_valid rises 2 clk cycles after the pixel_valid
//         that completes the window
//assumes: pixel_x_in is between 0 and IMG_WIDTH - 1 (it addresses the line
//         buffers)
//notes:   window edges wrap to the previous line and frame, there is no border
//         handling. sobel has an internal register stage, so the other
//         filters, the coordinates and valid are delayed one cycle to match

module image_transform #(
    parameter int IMG_WIDTH = 320,
    parameter int IMG_HEIGHT = 240,
    parameter int WINDOW_SIZE = 3,
    parameter int CHANNEL_DEPTH = 4
)(
    input logic clk,
    input logic rst,
    input logic pixel_valid,

    input logic [2:0] transform_sel,

    input  logic [((CHANNEL_DEPTH * 3) - 1):0] pixel_in,
    input  logic [($clog2(IMG_WIDTH) - 1):0]  pixel_x_in,
    input  logic [($clog2(IMG_HEIGHT) - 1):0] pixel_y_in,

    output logic [((CHANNEL_DEPTH * 3) - 1):0] pixel_out,
    output logic [($clog2(IMG_WIDTH) - 1):0]  pixel_x_out,
    output logic [($clog2(IMG_HEIGHT) - 1):0] pixel_y_out,
    output logic pixel_out_valid
);

    localparam int PIXEL_WIDTH = CHANNEL_DEPTH * 3;
    localparam int X_WIDTH     = $clog2(IMG_WIDTH);
    localparam int Y_WIDTH     = $clog2(IMG_HEIGHT);
    localparam int COORD_WIDTH = X_WIDTH + Y_WIDTH;

    //the window centre lags pixel_in by one line through line_buffer_0 plus
    //two taps through the window register
    localparam int LATENCY = IMG_WIDTH + 2;

    //line buffer logic

    logic [(PIXEL_WIDTH - 1):0] line_buffer_0_pixel_out;
    logic [(PIXEL_WIDTH - 1):0] line_buffer_1_pixel_out;

    line_buffer #(
        .WIDTH      (IMG_WIDTH),
        .DATA_WIDTH (PIXEL_WIDTH)
    ) line_buffer_0_inst (
        .clk         (clk),
        .rst         (rst),
        .pixel_valid (pixel_valid),
        .addr        (pixel_x_in),
        .data_in     (pixel_in),
        .data_out    (line_buffer_0_pixel_out)
    );

    line_buffer #(
        .WIDTH      (IMG_WIDTH),
        .DATA_WIDTH (PIXEL_WIDTH)
    ) line_buffer_1_inst (
        .clk         (clk),
        .rst         (rst),
        .pixel_valid (pixel_valid),
        .addr        (pixel_x_in),
        .data_in     (line_buffer_0_pixel_out),
        .data_out    (line_buffer_1_pixel_out)
    );

    //tap logic

    logic [(PIXEL_WIDTH - 1):0] row_0_taps [(WINDOW_SIZE - 1):0];
    logic [(PIXEL_WIDTH - 1):0] row_1_taps [(WINDOW_SIZE - 1):0];
    logic [(PIXEL_WIDTH - 1):0] row_2_taps [(WINDOW_SIZE - 1):0];

    window_register #(
        .NUM_TAPS   (WINDOW_SIZE),
        .DATA_WIDTH (PIXEL_WIDTH)
    ) window_register_0_inst (
        .clk         (clk),
        .rst         (rst),
        .pixel_valid (pixel_valid),
        .data_in     (pixel_in),
        .taps        (row_0_taps)
    );

    window_register #(
        .NUM_TAPS   (WINDOW_SIZE),
        .DATA_WIDTH (PIXEL_WIDTH)
    ) window_register_1_inst (
        .clk         (clk),
        .rst         (rst),
        .pixel_valid (pixel_valid),
        .data_in     (line_buffer_0_pixel_out),
        .taps        (row_1_taps)
    );

    window_register #(
        .NUM_TAPS   (WINDOW_SIZE),
        .DATA_WIDTH (PIXEL_WIDTH)
    ) window_register_2_inst (
        .clk         (clk),
        .rst         (rst),
        .pixel_valid (pixel_valid),
        .data_in     (line_buffer_1_pixel_out),
        .taps        (row_2_taps)
    );

    //coordinate delay logic
    //the coordinates travel through the same structure as the pixels

    logic [(COORD_WIDTH - 1):0] coord_in;
    logic [(COORD_WIDTH - 1):0] coord_line_delayed;
    logic [(COORD_WIDTH - 1):0] coord_taps [(WINDOW_SIZE - 1):0];

    assign coord_in = {pixel_y_in, pixel_x_in};

    line_buffer #(
        .WIDTH      (IMG_WIDTH),
        .DATA_WIDTH (COORD_WIDTH)
    ) coord_line_buffer_inst (
        .clk         (clk),
        .rst         (rst),
        .pixel_valid (pixel_valid),
        .addr        (pixel_x_in),
        .data_in     (coord_in),
        .data_out    (coord_line_delayed)
    );

    window_register #(
        .NUM_TAPS   (WINDOW_SIZE),
        .DATA_WIDTH (COORD_WIDTH)
    ) coord_window_register_inst (
        .clk         (clk),
        .rst         (rst),
        .pixel_valid (pixel_valid),
        .data_in     (coord_line_delayed),
        .taps        (coord_taps)
    );

    logic [(COORD_WIDTH - 1):0] coord_out_d;

    always_ff @(posedge clk) begin
        coord_out_d <= coord_taps[1];
    end

    assign {pixel_y_out, pixel_x_out} = coord_out_d;

    //pipeline fill logic

    logic [($clog2(LATENCY + 1) - 1):0] fill_count;
    logic pipeline_full;
    logic pixel_valid_d;
    logic pixel_valid_dd; 

    assign pipeline_full = (fill_count == LATENCY);

    always_ff @(posedge clk) begin
        if (rst) begin
            fill_count <= '0;
        end else if (pixel_valid && !pipeline_full) begin
            fill_count <= fill_count + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            pixel_valid_d <= '0;
            pixel_valid_dd <= '0;
        end else begin
            pixel_valid_d <= pixel_valid;
            pixel_valid_dd <= pixel_valid_d;
        end
    end

    assign pixel_out_valid = pixel_valid_dd && pipeline_full;

    //transform logic

    logic [(PIXEL_WIDTH - 1):0] grayscale_pixel_out;

    grayscale_transform #(
        .CHANNEL_DEPTH (CHANNEL_DEPTH)
    ) grayscale_transform_inst (
        .pixel_in  (row_1_taps[1]),
        .pixel_out (grayscale_pixel_out)
    );
    
    logic [(PIXEL_WIDTH - 1):0] blur_pixel_out;
    
    blur_transform #(
        .CHANNEL_DEPTH (CHANNEL_DEPTH)
    ) blur_transform_inst (
        .taps  ({row_0_taps, row_1_taps, row_2_taps}),
        .pixel_out (blur_pixel_out)
    );
    
    logic [(PIXEL_WIDTH - 1):0] sharpen_pixel_out;
    
    sharpen_transform #(
        .CHANNEL_DEPTH (CHANNEL_DEPTH)
    ) sharpen_transform_inst (
        .taps  ({row_0_taps, row_1_taps, row_2_taps}),
        .pixel_out (sharpen_pixel_out)
    );
    
    logic [(PIXEL_WIDTH - 1):0] sobel_pixel_out;
    
    sobel_transform #(
        .CHANNEL_DEPTH (CHANNEL_DEPTH)
    ) sobel_transform_inst (
        .clk   (clk),
        .taps  ({row_0_taps, row_1_taps, row_2_taps}),
        .pixel_out (sobel_pixel_out)
    );

    logic [(PIXEL_WIDTH - 1):0] grayscale_pixel_out_d;
    logic [(PIXEL_WIDTH - 1):0] blur_pixel_out_d;
    logic [(PIXEL_WIDTH - 1):0] sharpen_pixel_out_d;
    logic [(PIXEL_WIDTH - 1):0] passthrough_pixel_out_d;

    always_ff @(posedge clk) begin
        grayscale_pixel_out_d   <= grayscale_pixel_out;
        blur_pixel_out_d        <= blur_pixel_out;
        sharpen_pixel_out_d     <= sharpen_pixel_out;
        passthrough_pixel_out_d <= row_1_taps[1];
    end

    //transform select logic

    always_comb begin
        case (transform_sel)
            3'b001: begin
                pixel_out = grayscale_pixel_out_d;
            end
            
            3'b010: begin
                pixel_out = blur_pixel_out_d;
            end
            
            3'b011: begin
                pixel_out = sharpen_pixel_out_d;
            end
            
            3'b100: begin
                pixel_out = sobel_pixel_out;
            end

            default: begin
                pixel_out = passthrough_pixel_out_d;
            end
        endcase
    end
endmodule
