module u_baud #(parameter XTAL_CLK = 50_000_000, BAUD = 2400) (
    input wire sys_clk,
    input wire sys_rst_l,
    output reg baud_tick
);
    localparam CLK_DIV = XTAL_CLK / (BAUD * 16);
    localparam CW = $clog2(CLK_DIV);
    reg [CW-1:0] counter;
    always @(posedge sys_clk or negedge sys_rst_l) begin
        if(!sys_rst_l) begin
            counter <= 0;
            baud_tick <= 0;
        end else begin
            if(counter == CLK_DIV-1) begin
                baud_tick <= 1'b1;
                counter <= 0;
            end else begin
                baud_tick <= 1'b0;
                counter <= counter + 1;
            end
        end
    end
endmodule