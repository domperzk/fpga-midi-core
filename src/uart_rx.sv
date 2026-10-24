`timescale 1ns / 1ps

// module: uart_rx
// purpose: asynchronous serial receiver configured for MIDI (8-N-1).
//          safely synchronises the external RX pin, generates a 16x 
//          oversampling tick, and uses a state machine to extract the byte.


module uart_rx #(
    parameter CLK_FREQ  = 100_000_000, // arty a7 clk
    parameter BAUD_RATE = 31250        // MIDI baud rate
)(
    input  logic       clk,         // 100MHz system clock
    input  logic       rst_n,       // arty a7 reset button
    input  logic       rx_pin,      // asynchronous UART wire
    output logic [7:0] data_byte,   // assembled MIDI byte
    output logic       data_ready   // 1-clock-cycle pulse when byte is valid
);


    localparam CLK_PER_TICK = CLK_FREQ / (BAUD_RATE * 16); 


     // async_reg tells vivado to leave as is
    (* ASYNC_REG = "TRUE" *) logic rx_meta; // metastable voltage 
    (* ASYNC_REG = "TRUE" *) logic rx_sync; // stable (when changed to 0, a byte is coming from MIDI)

    logic [7:0] baud_counter; // counts from 0-199 
    logic       tick_pulse; // 16x faster than midi baud rate


    logic [3:0] tick_counter; // trackers where we are inside the current bit (0-15)
    logic [2:0] bit_counter; // counts number of bits from MIDI payload
    logic [7:0] shift_reg; // holds bits

   // 2-flop synchroniser

    always_ff @(posedge clk) 
        begin
            if (!rst_n) begin
                rx_meta <= 1'b1;
                rx_sync <= 1'b1;
            end
        end else begin
            rx_meta <= rx_pin;
            rx_sync <= rx_meta;
        end
    
    // baud tick generator

    always_ff @(posedge clk)
    begin
        if (!rst_n) begin
            baud_counter <= '0;
        end
    
        else begin
            if (baud_counter == CLK_PER_TICK - 1) begin
            baud_counter <= '0;
            end
        
            else begin
                baud_counter <= baud_counter + 1;
            end 
        end
    end

    assign tick_pulse = (baud_counter == (CLK_PER_TICK - 1));

    // idle-start-data-stop Finite State Machine
   

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state;

    always_ff @(posedge clk) begin
        
        if (!rst_n) begin // default cases
            state <= IDLE;
            data_byte <= '0;
            data_ready <= '0;
            tick_counter <= '0;
            bit_counter <= '0;
            shift_reg <= '0; 
        end

        else begin
            data_ready <= '0;

            if (tick_pulse) begin
                case (state) 
                    IDLE: begin
                        if (rx_sync == 1) begin
                            state <= IDLE;
                        end 

                        else if (rx_sync == 0) begin
                            state <= START;
                            tick_counter <= 0;
                            bit_counter <= 0;
                        end
                    end

                    START: begin
                        if (tick_counter == 7 && rx_sync == 1) begin
                            state <= IDLE; // noise or glitch
                            
                        end

                        else if (tick_counter < 7) begin
                            state <= START;
                            tick_counter <= tick_counter + 1;

                        end
                        else if (tick_counter == 7 && rx_sync == 0) begin
                            state <= DATA;
                            tick_counter <= 0;
                        end
                    end

                    DATA: begin
                        if (tick_counter < 15) begin
                            state <= DATA;
                            tick_counter <= tick_counter + 1;

                        end
                        else if (tick_counter == 15 && bit_counter < 7) begin
                            state <= DATA;
                            shift_reg <= {rx_sync, shift_reg[7:1]};
                            bit_counter <= bit_counter + 1;
                            tick_counter <= 0;
                        end
                        else if (tick_counter == 15 && bit_counter == 7) begin
                            state <= STOP;
                            shift_reg <= {rx_sync, shift_reg[7:1]};
                            tick_counter <= 0;
                        end
                    end  

                    STOP: begin
                        if (tick_counter < 15) begin
                            state <= STOP;
                            tick_counter <= tick_counter + 1;

                        end
                        else if (tick_counter == 15) begin
                            state <= IDLE;
                            data_byte <= shift_reg;
                            data_ready <= 1;
                        end
                    end  
                    

                endcase
            end
        end
  
    end

endmodule