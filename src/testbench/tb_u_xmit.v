`timescale 1ns / 1ps
`default_nettype none

`include "inc.vh"

module tb_u_xmit;
    reg sys_clk;
    reg sys_rst_l;
    reg xmit_H;
    reg [7:0] xmit_dataH;
    wire uart_XMIT_dataH;
    wire xmit_active;
    wire xmit_doneH;

    uart #(.XTAL_CLK(256), .BAUD(2), .WORD_LEN(8)) dut (
        .sys_clk(sys_clk),
        .sys_rst_l(sys_rst_l),
        .xmit_H(xmit_H),
        .xmit_dataH(xmit_dataH),
        .uart_XMIT_dataH(uart_XMIT_dataH),
        .xmit_active(xmit_active),
        .xmit_doneH(xmit_doneH)
    );

    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk; // 100MHz clock
    end

    initial begin
        $dumpfile("tb_u_xmit.vcd");
        $dumpvars(0, tb_u_xmit);
        sys_rst_l = 0;
        xmit_H = 0;
        xmit_dataH = 8'h00;

        #20; // Wait for reset deassertion
        sys_rst_l = 1;

        #100; // Wait for some time after reset
        xmit_dataH = 8'hA6; // Example data to transmit
        xmit_H = 1; // Start transmission
        #10; 
        xmit_H = 0;

        #200; // Wait for transmission to complete
        xmit_H = 0; // Stop transmission

        #(1000 * 16); // Wait before ending simulation
        $finish;
    end
endmodule