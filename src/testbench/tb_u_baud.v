`include "u_baud.v"

module tb_u_baud;
    reg sys_clk, rst_n;
    wire clk_baud;

    u_baud #(.XTAL_CLK(50_000_000), .BAUD(115200)) baud_gen (
        .sys_clk(sys_clk),
        .sys_rst_l(rst_n),
        .baud_tick(clk_baud)
    );

    always #5 sys_clk = ~sys_clk;

    initial begin
        $dumpfile("tb_u_baud.vcd");
        $dumpvars(0, tb_u_baud);
        sys_clk = 1'b0; rst_n   = 1'b0; #100;
        rst_n = 1'b1; #10000;
        $finish;
    end
endmodule