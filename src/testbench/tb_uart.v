`timescale 1ns / 1ps
`default_nettype none

`include "inc.vh"

module tb_uart;
    reg sys_clk1, sys_clk2;
    reg sys_rst_l;
    reg xmit_H;
    reg [7:0] xmit_dataH;
    wire uart_XMIT_dataH;
    wire xmit_active;
    wire xmit_doneH;
    wire rec_ready1, rec_busy1;
    wire rec_ready2, rec_busy2;
    wire [7:0] rec_dataH1, rec_dataH2;

    uart #(.XTAL_CLK(100000000), .BAUD(115200), .WORD_LEN(8)) utx (    // Transmitter connected to same module with same clock as well as different module with different clock to test both scenarios
        .sys_clk(sys_clk1),
        .sys_rst_l(sys_rst_l),
        .xmit_H(xmit_H),
        .xmit_dataH(xmit_dataH),
        .uart_XMIT_dataH(uart_XMIT_dataH),
        .xmit_active(xmit_active),
        .xmit_doneH(xmit_doneH),
        .rec_readyH(rec_ready1),
        .rec_busy(rec_busy1),
        .rec_dataH(rec_dataH1),
        .uart_REC_dataH(uart_XMIT_dataH)
    );

    uart #(.XTAL_CLK(500000000), .BAUD(115200), .WORD_LEN(8)) urx (
        .sys_clk(sys_clk2),
        .sys_rst_l(sys_rst_l),
        .uart_REC_dataH(uart_XMIT_dataH),
        .rec_readyH(rec_ready2),
        .rec_busy(rec_busy2),
        .rec_dataH(rec_dataH2),
        .xmit_H(1'b0), // Not used in receiver, can be tied to a default value
        .xmit_dataH(8'h00) // Not used in receiver, can be tied to a default value
    );

    initial begin
        sys_clk1 = 0;
        forever #5 sys_clk1 = ~sys_clk1; // 100MHz clock
    end

    initial begin
        sys_clk2 = 0;
        forever #1 sys_clk2 = ~sys_clk2; // 500MHz clock 
    end

    initial begin
        $dumpfile("tb_uart.vcd");
        $dumpvars(1, tb_uart, tb_uart.utx.tx.baud_tick, tb_uart.urx.rx.baud_tick, tb_uart.utx.tx.pst, tb_uart.utx.tx.bit_count, tb_uart.utx.tx.tick_count, tb_uart.urx.rx.state, tb_uart.urx.rx.bit_count, tb_uart.urx.rx.tick_count);
        sys_rst_l = 0;
        xmit_H = 0;
        xmit_dataH = 8'h00;

        #200; // Wait for reset deassertion
        sys_rst_l = 1;

        #100; // Wait for some time after reset
        xmit_dataH = 8'h55; // Example data to transmit
        xmit_H = 1; // Start transmission
        repeat(2) @(posedge sys_clk1); // Wait for one clock cycle
        xmit_H = 0;

        #(100000); // Wait before ending simulation

        xmit_dataH = 8'hB5; // Example data to transmit
        xmit_H = 1; // Start transmission
        repeat(2)@(posedge sys_clk1); // Wait for one clock cycle
        xmit_H = 0;

        #(100000); // Wait before ending simulation
        $finish;
    end
endmodule