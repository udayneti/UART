`timescale 1ns / 1ps
`default_nettype none

module main_tb_uart;
    reg sys_clk1, sys_clk2, sys_clk3;
    reg sys_rst_l;
    reg xmit_H;
    reg [7:0] xmit_dataH;
    wire uart_XMIT_dataH;
    wire xmit_active;
    wire xmit_doneH;
    wire rec_ready1, rec_busy1;
    wire rec_ready2, rec_busy2;
    wire rec_ready3, rec_busy3;
    wire [7:0] rec_dataH1, rec_dataH2, rec_dataH3;

    initial begin
        sys_clk1 = 0;
        forever #10 sys_clk1 = ~sys_clk1; // 50MHz clock
    end

    initial begin
        sys_clk2 = 0;
        forever #50 sys_clk2 = ~sys_clk2; // 10MHz clock 
    end

    initial begin
        sys_clk3 = 0;
        forever #100 sys_clk3 = ~sys_clk3; // 1MHz clock
    end

    localparam bit_duration = 1000000000 / 9600; // Duration of one bit at 9600 baud in ns

    uart #(.XTAL_CLK(50_000_000), .BAUD(9600), .WORD_LEN(8)) utx (    // Transmitter connected to same module with same clock as well as different module with different clock to test both scenarios
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

    uart #(.XTAL_CLK(10_000_000), .BAUD(9600), .WORD_LEN(8)) urx (
        .sys_clk(sys_clk2),
        .sys_rst_l(sys_rst_l),
        .uart_REC_dataH(uart_XMIT_dataH),
        .rec_readyH(rec_ready2),
        .rec_busy(rec_busy2),
        .rec_dataH(rec_dataH2),
        .xmit_H(xmit_H),
        .xmit_dataH(xmit_dataH)
    );

    uart #(.XTAL_CLK(5_000_000), .BAUD(9600), .WORD_LEN(8)) urx_slow (
        .sys_clk(sys_clk3),
        .sys_rst_l(sys_rst_l),
        .uart_REC_dataH(uart_XMIT_dataH),
        .rec_readyH(rec_ready3),
        .rec_busy(rec_busy3),
        .rec_dataH(rec_dataH3),
        .xmit_H(xmit_H),
        .xmit_dataH(xmit_dataH)
    );

    task sys_reset;
        begin
            sys_rst_l = 0;
            #100;
            sys_rst_l = 1;
        end
    endtask

    task send_byte;
        input reg [7:0] data;
        begin
            wait(xmit_doneH);
            xmit_dataH = data;
            xmit_H = 1;
            repeat(2) @(posedge sys_clk1);
            xmit_H = 0;
            #(10 * bit_duration); // Wait for the duration of the entire byte to be transmitted
            #(2 * bit_duration); // Additional wait to ensure receiver goes into idle state
        end
    endtask

    task send_byte_later_reset;
        input reg [7:0] data;
        input integer delay;
        begin
            wait(xmit_doneH);
            xmit_dataH = data;
            xmit_H = 1;
            repeat(2) @(posedge sys_clk1);
            xmit_H = 0;
            #(delay); // Wait for the duration of the entire byte to be transmitted
            sys_reset(); // Reset the system in the middle of transmission to test robustness
        end
    endtask

    task send_continuous_bytes;
        input integer num_bytes;
        integer i;
        reg [7:0] data;
        begin
            for(i = 0; i < num_bytes; i = i + 1) begin
                data = $urandom;
                wait(xmit_doneH);
                xmit_dataH = data;
                xmit_H = 1;
                repeat(2) @(posedge sys_clk1);
                xmit_H = 0;
                #(9 * bit_duration); // Wait for the duration of the entire byte to be transmitted
                xmit_H = 1;
                #(bit_duration); // Short gap between bytes
                xmit_H = 0;
                check_received_byte(data, 1'b0); // Check if received data matches sent data
            end
        end
    endtask

    task pseudo_start_bit;
        begin
            wait(xmit_doneH);
            utx.tx.uart_XMIT_dataH = 0; // Drive line low to simulate start bit without using transmitter
            #(bit_duration / 3);
            utx.tx.uart_XMIT_dataH = 1; // Release line
            #(2 * bit_duration); // Wait for some time to observe receiver behavior
            check_received_byte(utx.tx.xmit_dataH, 1'b0); // Check if receiver correctly ignores this as it's not a valid transmission
        end
    endtask

    task invalid_states;
        begin
           utx.tx.txstate = 2'bxx;
		   utx.rx.rxstate = 2'bxx;
		   urx.tx.txstate = 2'bxx;
           urx.rx.rxstate = 2'bxx;
		   urx_slow.tx.txstate = 2'bxx;
		   urx_slow.rx.rxstate = 2'bxx;
           #(2 * bit_duration); // Wait for some time to observe behavior
           check_received_byte(8'h00, 1'b0); // Check if receiver correctly handles invalid states without crashing or producing incorrect data
        end
    endtask

    task negative_test;
        begin
            send_byte(8'hFF); // Send a byte with all bits high
            check_received_byte(8'h00, 1'b1); // Check if received data matches sent data
        end
    endtask

    task check_received_byte;
        input reg [7:0] expected_data;
        input reg err_expected; // Optional flag to indicate if an error is expected (for negative tests)
        fork
            begin
                wait(rec_ready1);
                #1;
                if(rec_dataH1 !== expected_data) begin
                    $display("Time: %0t, %s: Expected %h, received %h on utx", $time, (!err_expected ? "ERROR (REAL)" : "SUCCESS (Intentional Error)"), expected_data, rec_dataH1);
                end else begin
                    $display("Time: %0t, SUCCESS: Received expected data %h on utx", $time, rec_dataH1);
                end
            end
            begin
                wait(rec_ready2);
                #1;
                if(rec_dataH2 !== expected_data) begin
                    $display("Time: %0t, %s: Expected %h, received %h on urx", $time, (!err_expected ? "ERROR (REAL)" : "SUCCESS (Intentional Error)"), expected_data, rec_dataH2);
                end else begin
                    $display("Time: %0t, SUCCESS: Received expected data %h on urx", $time, rec_dataH2);
                end
            end
            begin
                wait(rec_ready3);
                #1;
                if(rec_dataH3 !== expected_data) begin
                    $display("Time: %0t, %s: Expected %h, received %h on urx_slow", $time, (!err_expected ? "ERROR (REAL)" : "SUCCESS (Intentional Error)"), expected_data, rec_dataH3);
                end else begin
                    $display("Time: %0t, SUCCESS: Received expected data %h on urx_slow", $time, rec_dataH3);
                end
            end
        join
    endtask

    task drivmonscore;
        integer i;
        reg [7:0] test_data;
        begin
            for(i = 1; i <= 5; i = i + 1) begin
                test_data = $urandom;
                send_byte(test_data); // Send some test data
                check_received_byte(test_data, 1'b0); // Check if received data matches sent data
            end
            send_byte_later_reset(8'hA5, bit_duration * 5); // Send byte and reset in the middle of transmission
            send_byte_later_reset(8'h3C, bit_duration / 3); // Send byte and reset during start bit
            check_received_byte(8'h00, 1'b0);
            send_continuous_bytes(10);
            pseudo_start_bit();
            invalid_states();
            negative_test();
        end
    endtask

    initial begin
        sys_reset();
        drivmonscore();
        $finish;
    end

    initial begin
        $dumpfile("main_tb_uart.vcd");
        $dumpvars(1, main_tb_uart, main_tb_uart.utx.tx.uart_XMIT_dataH);
    end

endmodule
