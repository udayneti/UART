
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

    localparam [1:0] IDLE = 0, START_BIT = 1, DATA_BITS = 2, STOP_BIT = 3;
    reg [1:0] txstate;
    reg [WORD_LEN-1:0] xmit_buffer;
    reg [`CW-1:0] bit_count;
    reg [3:0] tick_count;

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if(!sys_rst_l) begin
            txstate <= IDLE;
            uart_XMIT_dataH <= 1'b1;
            xmit_active <= 1'b0;
            xmit_doneH <= 1'b0;
            xmit_buffer <= 0;
            bit_count <= 0;
            tick_count <= 0;
        end else begin
            case(txstate)
                IDLE: begin
                    xmit_active <= 1'b0;
                    xmit_doneH <= 1'b1;
                    uart_XMIT_dataH <= 1'b1;
                    tick_count <= 0;
                    bit_count <= 0;
                    if(xmit_H) begin
                        xmit_buffer <= xmit_dataH;
                        txstate <= START_BIT;
                        xmit_active <= 1'b1;
                        xmit_doneH <= 1'b0;
                        uart_XMIT_dataH <= 1'b0;
                    end 
                end
                START_BIT: begin
                    xmit_active <= 1'b1;
                    xmit_doneH <= 1'b0;
                    uart_XMIT_dataH <= 1'b0;
                    if(baud_tick) begin
                        if(tick_count == 4'd15) begin
                            txstate <= DATA_BITS;
                            tick_count <= 0;
                            bit_count <= 0;
                        end
                        else tick_count <= tick_count + 1;
                    end
                end
                DATA_BITS: begin
                    xmit_active <= 1'b1;
                    xmit_doneH <= 1'b0;
                    uart_XMIT_dataH <= xmit_buffer[0];
                    if(baud_tick) begin
                        if(tick_count == 4'd15) begin
                            tick_count <= 0;
                            bit_count <= bit_count + 1'b1;
                            xmit_buffer <= {1'b1, xmit_buffer[WORD_LEN-1:1]};
                            txstate <= (bit_count == WORD_LEN - 1) ? STOP_BIT : DATA_BITS;
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end
                STOP_BIT: begin
                    uart_XMIT_dataH <= 1'b1;
                    xmit_active <= 1'b1;
                    xmit_doneH <= 1'b0;
                    if(baud_tick) begin
                        if(tick_count == 4'd15) begin
                            tick_count <= 0;
                            if(xmit_H) begin
                                xmit_buffer <= xmit_dataH;
                                txstate <= START_BIT;
                                xmit_doneH <= 1'b0;
                                xmit_active <= 1'b1;
                            end else begin
                                txstate <= IDLE;
                                xmit_doneH <= 1'b1;
                                xmit_active <= 1'b0;
                            end
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end
            endcase
        end
    end
endmodule