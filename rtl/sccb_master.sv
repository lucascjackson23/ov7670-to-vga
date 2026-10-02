`timescale 1ns / 1ps

//sccb_master
//write only sccb (i2c like) master. sends the 3 phase write the ov7670
//expects: id address, register address, register data
//
//clock:   clk (CLK_FREQ), sio_c runs at SIO_C_FREQ
//latency: one write takes about 30 sio_c periods (about 0.3 ms at 100 kHz).
//         busy is high for the whole write
//assumes: id_addr, reg_addr and reg_data stay stable while busy is high
//         (they are not latched)
//notes:   sio_d is open drain. sio_d_oe high pulls the line low, low
//         releases it to the pull-up. the 9th (don't care) bit of each phase
//         is released and the ack is not checked

module sccb_master #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int SIO_C_FREQ = 100_000
)(
    input logic clk,
    input logic rst,
    
    input logic start_write,
    input  logic [7:0]  id_addr,
    input  logic [7:0]  reg_addr,
    input  logic [7:0]  reg_data,
    
    output logic sio_c,
    output logic sio_d_oe,
    
    output logic busy
);

    //phase logic

    localparam int SIO_C_PHASE_TICK_FREQ = SIO_C_FREQ * 4;
    localparam int CLKS_PER_SIO_C_PHASE_TICK = CLK_FREQ / SIO_C_PHASE_TICK_FREQ;
    
    logic sio_c_phase_tick;
    logic [1:0] sio_c_phase;
    logic [($clog2(CLKS_PER_SIO_C_PHASE_TICK) - 1):0] sio_c_div_cnt;
    
    assign sio_c_phase_tick = sio_c_div_cnt == (CLKS_PER_SIO_C_PHASE_TICK - 1);
    
    always_ff @(posedge clk) begin
        if (rst) begin
            sio_c_phase <= '0;
            sio_c_div_cnt <= '0;
        end else begin
            if (sio_c_phase_tick) begin
                sio_c_div_cnt <= '0;
                sio_c_phase   <= sio_c_phase + 1'b1;
            end else begin
                sio_c_div_cnt <= sio_c_div_cnt + 1'b1;
            end
        end
    end
    
    //byte and bit select logic
    
    logic [1:0] byte_sel;
    logic [3:0] bit_sel;
    logic [7:0] data_byte;
    logic data_bit;
    
    always_comb begin
        case (byte_sel)
            2'd0: begin
                data_byte = id_addr;
            end
            
            2'd1: begin
                data_byte = reg_addr;
            end
            
            2'd2: begin
                data_byte = reg_data;
            end
            
            default: begin
                data_byte = 8'hFF;
            end
        endcase
        
        if (bit_sel != 4'd8) begin
            data_bit = data_byte[3'd7 - bit_sel[2:0]];
        end else begin
            data_bit = 1'b1;
        end
    end
    
    //state logic
    
    typedef enum logic [2:0] {
        IDLE      = 3'd0,
        START     = 3'd1,
        SEND_BYTE = 3'd2,
        STOP      = 3'd3
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            busy <= '0;
        end else if (!busy) begin
            busy <= start_write;
        end else begin
            busy <= !(sio_c_phase_tick && (state == STOP) && (sio_c_phase == 2'd3));
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else if (sio_c_phase_tick && (sio_c_phase == 2'd3)) begin
            state <= next_state;
        end
    end
    
    always_comb begin
        case (state)
            IDLE: begin
                if (busy && sio_c_phase == 2'd3) begin
                    next_state = START;
                end else begin
                    next_state = IDLE;
                end
            end
            
            START: begin
                next_state = SEND_BYTE;
            end
            
            SEND_BYTE: begin
                if ((byte_sel == 2'd2) && (bit_sel == 4'd8)) begin
                    next_state = STOP;
                end else begin
                    next_state = SEND_BYTE;
                end 
            end
            
            STOP: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin
            sio_c    <= 1'b1;
            sio_d_oe <= 1'b0;
            byte_sel <= '0;
            bit_sel  <= '0;
        end else if (sio_c_phase_tick) begin
            case (state)
                IDLE: begin
                    sio_c <= 1'b1;
                    sio_d_oe <= '0; 
                end
                
                START: begin
                    case (sio_c_phase)
                        2'd0: begin
                            sio_c <= 1'b1;
                            sio_d_oe <= '0; 
                        end
                        
                        2'd1: begin
                            sio_c <= 1'b1;
                            sio_d_oe <= 1'b1;
                        end
                        
                        2'd2: begin
                            sio_c <= 1'b1;
                            sio_d_oe <= 1'b1;
                        end
                        
                        2'd3: begin
                            sio_c <= '0;
                            sio_d_oe <= 1'b1;
                            byte_sel <= '0;
                            bit_sel <= '0;
                        end
                    endcase
                end
                
                SEND_BYTE: begin
                    case (sio_c_phase)
                        2'd0: begin
                            sio_c <= '0;
                            sio_d_oe <= ~data_bit; 
                        end
                        
                        2'd1: begin
                            sio_c <= 1'b1;
                            sio_d_oe <= ~data_bit;
                        end
                        
                        2'd2: begin
                            sio_c <= 1'b1;
                            sio_d_oe <= ~data_bit;
                        end
                        
                        2'd3: begin
                            sio_c <= '0;
                            sio_d_oe <= ~data_bit; 
                            
                            if (bit_sel == 4'd8) begin
                                bit_sel <= '0;
                            
                                if (byte_sel < 2'd2) begin
                                    byte_sel <= byte_sel + 1'b1;
                                end 
                            end else begin
                                bit_sel <= bit_sel + 1'b1;
                            end
                        end
                    endcase
                end
                
                STOP: begin
                    case (sio_c_phase)
                        2'd0: begin
                            sio_c <= '0;
                            sio_d_oe <= 1'b1;
                        end
                        
                        2'd1: begin
                            sio_c <= 1'b1;
                            sio_d_oe <= 1'b1;
                        end
                        
                        2'd2: begin
                            sio_c <= 1'b1;
                            sio_d_oe <= 1'b1;
                        end
                        
                        2'd3: begin
                            sio_c <= 1'b1;
                            sio_d_oe <= '0;
                        end
                    endcase
                end
            endcase
        end        
    end
endmodule
