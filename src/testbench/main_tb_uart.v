`timescale 1ns / 1ps
`default_nettype none

module main_tb_uart;
    reg sys_clk1, sys_clk2, sys_clk3, sys_clk4;
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
        forever #5 sys_clk1 = ~sys_clk1; // 500MHz clock
    end

    initial begin
        sys_clk2 = 0;
        forever #1 sys_clk2 = ~sys_clk2; // 100MHz clock 
    end

    initial begin
        sys_clk3 = 0;
        forever #10 sys_clk3 = ~sys_clk3; // 50MHz clock
    end

    localparam bit_duration_115200 = 1000000000 / 115200; // Duration of one bit at 115200 baud in ns

    uart #(.XTAL_CLK(100_000_000), .BAUD(115200), .WORD_LEN(8)) utx (    // Transmitter connected to same module with same clock as well as different module with different clock to test both scenarios
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

    uart #(.XTAL_CLK(500_000_000), .BAUD(115200), .WORD_LEN(8)) urx (
        .sys_clk(sys_clk2),
        .sys_rst_l(sys_rst_l),
        .uart_REC_dataH(uart_XMIT_dataH),
        .rec_readyH(rec_ready2),
        .rec_busy(rec_busy2),
        .rec_dataH(rec_dataH2),
        .xmit_H(1'b0), // Not used in receiver, can be tied to a default value
        .xmit_dataH(8'h00) // Not used in receiver, can be tied to a default value
    );

    uart #(.XTAL_CLK(50_000_000), .BAUD(115200), .WORD_LEN(8)) urx_slow (
        .sys_clk(sys_clk3),
        .sys_rst_l(sys_rst_l),
        .uart_REC_dataH(uart_XMIT_dataH),
        .rec_readyH(rec_ready3),
        .rec_busy(rec_busy3),
        .rec_dataH(rec_dataH3),
        .xmit_H(1'b0), // Not used in receiver, can be tied to a default value
        .xmit_dataH(8'h00) // Not used in receiver, can be tied to a default value
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
            #(10 * bit_duration_115200); // Wait for the duration of the entire byte to be transmitted
            #(2 * bit_duration_115200); // Additional wait to ensure receiver goes into idle state
        end
    endtask

    task send_byte_later_reset;
        input reg [7:0] data;
        begin
            wait(xmit_doneH);
            xmit_dataH = data;
            xmit_H = 1;
            repeat(2) @(posedge sys_clk1);
            xmit_H = 0;
            #(5 * bit_duration_115200); // Wait for the duration of the entire byte to be transmitted
            sys_reset(); // Reset the system in the middle of transmission to test robustness
            #(5 * bit_duration_115200); // Wait for some time after reset to observe behavior
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
                #(9 * bit_duration_115200); // Wait for the duration of the entire byte to be transmitted
                xmit_H = 1;
                #(bit_duration_115200); // Short gap between bytes
                xmit_H = 0;
                check_received_byte(data); // Check if received data matches sent data
            end
        end
    endtask

    task pseudo_start_bit;
        begin
            wait(xmit_doneH);
            #(bit_duration_115200);
            utx.tx.uart_XMIT_dataH = 0; // Drive line low to simulate start bit without using transmitter
            repeat(2) @(posedge sys_clk1);
            utx.tx.uart_XMIT_dataH = 1; // Release line to simulate stop bit
            #(2 * bit_duration_115200); // Wait for some time to observe receiver behavior
            check_received_byte(utx.tx.xmit_dataH); // Check if receiver correctly ignores this as it's not a valid transmission
            if(rec_busy1 || rec_busy2 || rec_busy3) begin
                $display("Time: %0t, ERROR: Receiver should not be busy after pseudo start bit", $time);
            end else begin
                $display("Time: %0t, SUCCESS: Receivers correctly ignored pseudo start bit", $time);
            end
        end
    endtask


    task check_received_byte;
        input reg [7:0] expected_data;
        fork
            begin
                wait(rec_ready1);
                #1;
                if(rec_dataH1 !== expected_data) begin
                    $display("Time: %0t, ERROR: Expected %h but received %h on utx", $time, expected_data, rec_dataH1);
                end else begin
                    $display("Time: %0t, SUCCESS: Received expected data %h on utx", $time, rec_dataH1);
                end
            end
            begin
                wait(rec_ready2);
                #1;
                if(rec_dataH2 !== expected_data) begin
                    $display("Time: %0t, ERROR: Expected %h but received %h on urx", $time, expected_data, rec_dataH2);
                end else begin
                    $display("Time: %0t, SUCCESS: Received expected data %h on urx", $time, rec_dataH2);
                end
            end
            begin
                wait(rec_ready3);
                #1;
                if(rec_dataH3 !== expected_data) begin
                    $display("Time: %0t, ERROR: Expected %h but received %h on urx_slow", $time, expected_data, rec_dataH3);
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
                check_received_byte(test_data); // Check if received data matches sent data
            end
            send_byte_later_reset(8'hA5);
            check_received_byte(8'h00);
            send_continuous_bytes(10);
            pseudo_start_bit();
        end
    endtask

    initial begin
        sys_reset();
        drivmonscore();
        $finish;
    end

    initial begin
        $dumpfile("main_tb_uart.vcd");
        $dumpvars(1, main_tb_uart, main_tb_uart.utx.tx.txstate);
    end

endmodule