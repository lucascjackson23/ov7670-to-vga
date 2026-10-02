`timescale 1ns / 1ps

//ov7670_init_sequencer
//holds the camera in reset, then writes each register in ov7670_init.mem to
//the camera through sccb_master, one at a time
//
//clock:   clk (CLK_FREQ)
//latency: RESET_MS in reset, SETTLE_MS settle, then DELAY_MS after each of
//         the NUM_REGS - 1 writes. around 0.4 s total with the defaults
//assumes: NUM_REGS equals the number of words in ov7670_init.mem, including
//         the sccb id word at rom[0]. busy from sccb_master rises after
//         start_write and falls when the write is finished

module ov7670_init_sequencer #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int DELAY_MS = 5,
    parameter int RESET_MS = 10,
    parameter int SETTLE_MS = 2,
    parameter int NUM_REGS = 75
)(
    input logic clk,
    input logic rst,

    output logic [7:0] id_addr,
    output logic [7:0] reg_addr,
    output logic [7:0] reg_data,
    output logic start_write,
    input  logic busy,

    output logic ov7670_reset_n,
    output logic done
);

    //delay logic

    localparam int DELAY_CYCLES  = (CLK_FREQ / 1000) * DELAY_MS;
    localparam int RESET_CYCLES  = (CLK_FREQ / 1000) * RESET_MS;
    localparam int SETTLE_CYCLES = (CLK_FREQ / 1000) * SETTLE_MS;

    localparam int MAX_CYCLES = (RESET_CYCLES > SETTLE_CYCLES) ?
                                ((RESET_CYCLES > DELAY_CYCLES) ? RESET_CYCLES : DELAY_CYCLES) :
                                ((SETTLE_CYCLES > DELAY_CYCLES) ? SETTLE_CYCLES : DELAY_CYCLES);

    logic delay_tick;
    logic [($clog2(MAX_CYCLES) - 1):0] delay_cnt;

    assign delay_tick = delay_cnt == '0;

    //rom logic
    //rom[0] holds the SCCB id address in its low byte
    //rom[1] onwards holds {reg_addr, reg_data} pairs

    localparam int ROM_ADDR_W  = $clog2(NUM_REGS);
    localparam int FIRST_REG   = 1;

    logic [15:0] rom [0:(NUM_REGS - 1)];
    logic [(ROM_ADDR_W - 1):0] rom_addr;

    initial $readmemh("ov7670_init.mem", rom);

    assign reg_addr = rom[rom_addr][15:8];
    assign reg_data = rom[rom_addr][7:0];

    //state logic

    typedef enum logic [2:0] {
        CAM_RESET = 3'd0,
        SETTLE    = 3'd1,
        REQUEST   = 3'd2,
        WAIT_DONE = 3'd3,
        DELAY     = 3'd4,
        FINISHED  = 3'd5
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= CAM_RESET;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            CAM_RESET: begin
                if (delay_tick) begin
                    next_state = SETTLE;
                end else begin
                    next_state = CAM_RESET;
                end
            end

            SETTLE: begin
                if (delay_tick) begin
                    next_state = REQUEST;
                end else begin
                    next_state = SETTLE;
                end
            end

            REQUEST: begin
                if (busy) begin
                    next_state = WAIT_DONE;
                end else begin
                    next_state = REQUEST;
                end
            end

            WAIT_DONE: begin
                if (!busy) begin
                    next_state = DELAY;
                end else begin
                    next_state = WAIT_DONE;
                end
            end

            DELAY: begin
                if (delay_tick) begin
                    if (rom_addr == (NUM_REGS - 1)) begin
                        next_state = FINISHED;
                    end else begin
                        next_state = REQUEST;
                    end
                end else begin
                    next_state = DELAY;
                end
            end

            FINISHED: begin
                next_state = FINISHED;
            end

            default: begin
                next_state = CAM_RESET;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            start_write    <= '0;
            done           <= '0;
            ov7670_reset_n <= '0;
            id_addr        <= rom[0][7:0];
            rom_addr       <= FIRST_REG;
            delay_cnt      <= (RESET_CYCLES - 1);
        end else begin
            case (state)
                CAM_RESET: begin
                    start_write    <= '0;
                    done           <= '0;
                    ov7670_reset_n <= '0;
                    id_addr        <= rom[0][7:0];
                    rom_addr       <= FIRST_REG;

                    if (!delay_tick) begin
                        delay_cnt <= delay_cnt - 1'b1;
                    end else begin
                        delay_cnt <= (SETTLE_CYCLES - 1);
                    end
                end

                SETTLE: begin
                    ov7670_reset_n <= 1'b1;

                    if (!delay_tick) begin
                        delay_cnt <= delay_cnt - 1'b1;
                    end
                end

                REQUEST: begin
                    start_write <= 1'b1;
                    delay_cnt   <= (DELAY_CYCLES - 1);
                end

                WAIT_DONE: begin
                    start_write <= '0;
                end

                DELAY: begin
                    if (!delay_tick) begin
                        delay_cnt <= delay_cnt - 1'b1;
                    end else if (rom_addr < (NUM_REGS - 1)) begin
                        rom_addr <= rom_addr + 1'b1;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
