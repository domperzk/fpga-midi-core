`timescale 1ns / 1ps


module tb_midi_parser;
    
    logic       clk;
    logic       rst_n;
    logic [7:0] data_byte;
    logic       data_ready;
    logic       note_valid;
    logic [7:0] note_value;

    midi_parser inst1(
        .clk(clk),
        .rst_n(rst_n),
        .data_byte(data_byte),
        .data_ready(data_ready),
        .note_valid(note_valid),
        .note_value(note_value)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_midi_parser);
        clk = 0;

        rst_n = 0;
        data_byte = 0;
        data_ready = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        // initial test (checking note_value and note_valid are consistent)

        send_byte(8'h90);
        send_byte(8'h3C);
        send_byte(8'h40);

        repeat(30) @(posedge clk);

        // wrong channel test

        send_byte(8'h91); // channel 1 note on
        send_byte(8'b10100111);
        repeat(5) @(posedge clk);
        send_byte(8'hE0); // pitch bend
        send_byte(8'b01011001);

        repeat(30) @(posedge clk);

        // slow uart test 

        send_byte(8'h90); 
        repeat(50) @(posedge clk);
        send_byte(8'h3C); // middle C
        repeat(50) @(posedge clk);
        send_byte(8'h40);

        repeat(30) @(posedge clk);

        // mid transmission panic reset

        send_byte(8'h90);
        send_byte(8'h3C);
        rst_n <= 0;
        repeat(3) @(posedge clk);
        rst_n <= 1;
        send_byte(8'h40);

        $finish;
    end

    task automatic
        
        send_byte(input logic [7:0] byte_to_send);
            data_byte <= byte_to_send ;
            data_ready <= 1;
            @(posedge clk);
            data_ready <= 0;
            repeat(10) @(posedge clk);

    endtask


    
endmodule