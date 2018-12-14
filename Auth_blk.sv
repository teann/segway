module Auth_blk(clk, rst_n, RX, rider_off, pwr_up);

	input clk, rst_n, RX, rider_off;
//Define inputs, outputs and external signals
	logic [7:0] rx_data;
	logic rx_rdy, clr_rx_rdy;

	typedef enum logic [2:0] {OFF, PWR1, PWR2} state_t;
	state_t state, nxt_state;

	output logic pwr_up;

	UART_rcv uart(.clk(clk), .rst_n(rst_n), .RX(RX), 
			.clr_rdy(clr_rx_rdy),
			.rx_data(rx_data), .rdy(rx_rdy));
//State Transition flop
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= OFF;
		else
			state <= nxt_state;
//State machine that controls whether or not the segway is on or off
	always_comb begin
		nxt_state = OFF;
		pwr_up = 0;
		clr_rx_rdy = 0;
	//Depends on go signal 0x67, or stop signal 0x73 to start or stop
		case(state)
			OFF: if(rx_rdy && rx_data == 8'h67) begin
				pwr_up = 1;
				nxt_state = PWR1;
				clr_rx_rdy = 1;
			end			
			PWR1: if(rx_data == 8'h73 && rx_rdy) begin
				clr_rx_rdy = 1;
				if(rider_off) begin
					nxt_state = OFF;
				end 
				else begin
					pwr_up = 1;
					nxt_state = PWR2;
				end
			end	
			else begin
				nxt_state = PWR1;
				pwr_up = 1;
			end		
//PWR2 stage is like an intermediate stage that wameans our rider is off 			
			PWR2: if(rx_rdy && rx_data == 8'h73 && rider_off) begin
				clr_rx_rdy = 1;
				nxt_state = OFF;
			end	
			else if(rx_rdy && rx_data == 8'h67) begin
				clr_rx_rdy = 1;
				nxt_state = PWR1;
				pwr_up = 1;
			end	
			else begin
				nxt_state = PWR2;
				pwr_up = 1;
			end	
			default:
				nxt_state = OFF;
		endcase
	end

endmodule
