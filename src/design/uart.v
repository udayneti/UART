`include "inc.vh"
`default_nettype none

module uart #(parameter XTAL_CLK = `XTAL_CLK, BAUD = `BAUD, WORD_LEN = `WORD_LEN) (
    input wire sys_clk,
    input wire sys_rst_l,
    input wire xmit_H,
    input wire [WORD_LEN-1:0] xmit_dataH,
    input wire uart_REC_dataH,
    output wire uart_XMIT_dataH,
    output wire xmit_active,
    output wire xmit_doneH,
    output wire rec_readyH, 
    output wire rec_busy,
    output wire [WORD_LEN-1:0] rec_dataH
);

    wire baud_tick;
    u_baud #(.XTAL_CLK(XTAL_CLK), .BAUD(BAUD)) baud_gen (
        .sys_clk(sys_clk),
        .sys_rst_l(sys_rst_l),
        .baud_tick(baud_tick)
    );

    u_xmit #(.BAUD(BAUD), .WORD_LEN(WORD_LEN)) tx (
        .sys_clk(sys_clk),
        .sys_rst_l(sys_rst_l),
        .baud_tick(baud_tick),
        .xmit_H(xmit_H),
        .xmit_dataH(xmit_dataH),
        .uart_XMIT_dataH(uart_XMIT_dataH),
        .xmit_active(xmit_active),
        .xmit_doneH(xmit_doneH)
    );

    u_rec #(.BAUD(BAUD), .WORD_LEN(WORD_LEN)) rx (
        .sys_clk(sys_clk),
        .sys_rst_l(sys_rst_l),
        .baud_tick(baud_tick),
        .uart_REC_dataH(uart_REC_dataH),
        .rec_readyH(rec_readyH),
        .rec_busy(rec_busy),
        .rec_dataH(rec_dataH)
    );
endmodule