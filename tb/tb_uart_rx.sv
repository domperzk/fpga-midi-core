`timescale 1ns / 1ps

module tb_uart_rx;
    logic       clk;        // 100MHz system clock
    logic       rst_n;       // arty a7 reset button
    logic       rx_pin;      // asynchronous UART wire
    logic [7:0] data_byte;   // assembled MIDI byte
    logic       data_ready;   // 1-clock-cycle pulse when byte is valid


    uart_rx inst1(
        .clk(clk),
        .rst_n(rst_n),
        .rx_pin(rx_pin),
        .data_byte(data_byte),
        .data_ready(data_ready)
    );

    always #5 clk = ~clk; // simulated clock

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_uart_rx);
        clk = 0;
        rst_n = 0;
        rx_pin = 1;

        #20; // wait for possible metastability
        rst_n = 1;

        #100;
        send_byte(8'h3C);
        $finish;
    end

    task automatic
        
        send_byte(input logic [7:0] data_to_send);
        rx_pin = 0; // midi start bit
        #32000; 
        for (int i = 0; i < 8 ; i++ ) begin
            rx_pin = data_to_send[i];
            #32000;
        end
        rx_pin = 1; // midi stop bit
        #32000; 
    endtask
endmodule