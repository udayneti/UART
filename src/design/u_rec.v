`default_nettype none
`include "inc.vh"

module u_rec #(parameter BAUD = `BAUD, WORD_LEN = `WORD_LEN) (
    input wire sys_clk,
    input wire sys_rst_l,
    input wire baud_tick,
    input wire uart_REC_dataH,
    output reg rec_readyH,
    output reg rec_busy,
    output reg [WORD_LEN-1:0] rec_dataH
);

    localparam [1:0] IDLE = 0, START_BIT = 1, DATA_BITS = 2, STOP_BIT = 3;
    reg [1:0] rxstate;
    reg [WORD_LEN-1:0] rec_buffer;
    reg [`CW-1:0] bit_count;
    reg [3:0] tick_count;
    reg rsync1, rsync2;

    // 2 Flip-Flop synchronizer
    always @(posedge sys_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            rsync1 <= 1'b1;
            rsync2 <= 1'b1;
        end else begin
            rsync1 <= uart_REC_dataH;
            rsync2 <= rsync1;
        end
    end

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            rxstate <= IDLE;
            rec_readyH <= 1'b0;
            rec_busy <= 1'b0;
            rec_buffer <= 0;
            bit_count <= 0;
            tick_count <= 0;
            rec_dataH <= 0;
        end else begin
            case (rxstate)
                IDLE: begin
                    rec_readyH <= 1'b1;
                    rec_busy   <= 1'b0;
                    tick_count <= 0;
                    bit_count  <= 0;
                    if (!rsync2) begin
                        rxstate <= START_BIT;
                        rec_busy <= 1'b1;
                        tick_count <= 1;
                    end
                end

                START_BIT: begin
                    rec_readyH <= 1'b0;
                    if (baud_tick) begin
                        if (tick_count == 4'd7) begin
                            if (rsync2) begin
                                rxstate <= IDLE;
                            end else begin
                                tick_count <= tick_count + 1;
                            end
                        end else if (tick_count == 4'd15) begin
                            rxstate <= DATA_BITS;
                            tick_count <= 0;
                            bit_count <= 0;
                        end else begin
                            tick_count <= tick_count + 1;
                        end
                    end
                end

                DATA_BITS: begin
                    rec_readyH <= 1'b0;
                    if (baud_tick) begin
                        if (tick_count == 4'd7) begin
                            rec_buffer <= {rsync2, rec_buffer[WORD_LEN-1:1]};
                            tick_count <= tick_count + 1;
                        end else if (tick_count == 4'd15) begin
                            tick_count <= 0;
                            if (bit_count == WORD_LEN - 1) begin
                                rxstate <= STOP_BIT;
                            end else begin
                                bit_count <= bit_count + 1;
                            end
                        end else begin
                            tick_count <= tick_count + 1;
                        end
                    end
                end

                STOP_BIT: begin
                    if (baud_tick) begin
                        if (tick_count == 4'd15) begin
                            rxstate <= IDLE;
                            rec_readyH <= 1'b1;
                            rec_busy   <= 1'b0;
                            rec_dataH <= rec_buffer;
                            tick_count <= 0;
                        end else begin
                            tick_count <= tick_count + 1;
                        end
                    end
                end
            endcase
        end
    end
endmodule