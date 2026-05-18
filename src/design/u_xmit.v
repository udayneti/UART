
`default_nettype none
`include "inc.vh"

module u_xmit #(parameter BAUD = `BAUD, WORD_LEN = `WORD_LEN) (
    input wire sys_clk,
    input wire sys_rst_l,
    input wire xmit_H,
    input wire baud_tick,
    input wire [WORD_LEN-1:0] xmit_dataH,
    output reg uart_XMIT_dataH,
    output reg xmit_active,
    output reg xmit_doneH
);

    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] pst, nst;
    reg [WORD_LEN-1:0] xmit_buffer;
    reg [`CW-1:0] bit_count;
    reg [3:0] tick_count;

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if(!sys_rst_l) begin
            pst <= IDLE;
        end else begin
            pst <= nst;
        end
    end

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if(!sys_rst_l) begin
            uart_XMIT_dataH <= 1'b1;
            xmit_active <= 1'b0;
            xmit_doneH <= 1'b0;
            xmit_buffer <= 0;
            bit_count <= 0;
            tick_count <= 0;
        end else begin
            case(pst)
                IDLE: begin
                    xmit_active <= 1'b0;
                    xmit_doneH <= 1'b1;
                    uart_XMIT_dataH <= 1'b1;
                    tick_count <= 0;
                    bit_count <= 0;
                    if(xmit_H) begin
                        xmit_buffer <= xmit_dataH;
                        xmit_doneH <= 1'b0;
                    end 
                end
                START: begin
                    xmit_active <= 1'b1;
                    uart_XMIT_dataH <= 1'b0;
                    if(baud_tick) begin
                        if(tick_count == 4'd15) tick_count <= 0; 
                        else tick_count <= tick_count + 1;
                    end
                end
                DATA: begin
                    if(baud_tick) begin
                        uart_XMIT_dataH <= xmit_buffer[0];
                        if(tick_count == 4'd15) begin
                            tick_count <= 0;
                            bit_count <= bit_count + 1'b1;
                            xmit_buffer <= {1'b1, xmit_buffer[WORD_LEN-1:1]};
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end
                STOP: begin
                    uart_XMIT_dataH <= 1'b1;
                    if(baud_tick) begin
                        if(tick_count == 4'd15) tick_count <= 0;
                        else tick_count <= tick_count + 1'b1;
                    end
                end
                default: begin
                    uart_XMIT_dataH <= 1'b1;
                    xmit_active <= 1'b0;
                    xmit_doneH <= 1'b1;
                    tick_count <= 0;
                    bit_count <= 0;
                end
            endcase
        end
    end

    always @(*) begin
        case(pst)
            IDLE: begin
                if(xmit_H) nst = START;
                else nst = IDLE;
            end
            START: begin
                if(baud_tick && tick_count == 4'd15) nst = DATA;
                else nst = START;
            end
            DATA: begin
                if(baud_tick && tick_count == 4'd15 && bit_count == WORD_LEN - 1) 
                    nst = STOP;
                else 
                    nst = DATA;
            end
            STOP: begin
                if(baud_tick && tick_count == 4'd15) nst = IDLE;
                else nst = STOP;
            end
            default: nst = pst;
        endcase
    end
endmodule

// To Fix: 
// 1. In the STOP state, xmit_doneH should be set to 1 for only 1 cycle after the stop bit is sent, which is after tick_count reaches 15. Currently, it is not being set, which may cause issues in the testbench when waiting for the transmission to complete.
// 2. next bit should be sent after 16 baud ticks. but it is not handled properly. next bit is sent after 15 ticks. This can cause timing issues in the transmission, especially at higher baud rates. The condition should be changed to check for tick_count == 4'd15 before sending the next bit, and then reset tick_count to 0 for the next bit.
// 3. In STOP state, if xmit_H is asserted again, it should directly go to start state to start new transmission. Currently, it will wait for the current transmission to complete before starting a new one, which can cause delays in back-to-back transmissions. The state transition logic should be updated to allow transitioning from STOP to START if xmit_H is asserted, even if the current transmission has not completed yet.