module A2D_Intf(clk, rst_n, MISO, nxt, lft_ld, rght_ld, batt, SCLK, MOSI, SS_n);

//define inputs
	input clk, rst_n;
	input nxt;
	input MISO;
//define internal signals
	logic [1:0] rnd_cnt;
	logic en1, en2, en3;
	logic update;
	logic wrt;
	logic done;
	logic [2:0] chnl;
	logic [15:0] cmd, rd_data;
//define state machine
	typedef enum logic [2:0] {IDLE, SEND1, DEAD, SEND2} state_t;
	state_t state, nxt_state;
//define outputs
	output logic [11:0] lft_ld, rght_ld;
	output logic [11:0] batt;
	output logic MOSI;
	output logic SCLK;
	output logic SS_n;
//instantiate spi master for spi transactions
	SPI_mstr16 mstr(.clk(clk), .rst_n(rst_n),.wrt(wrt), 
			.cmd(cmd), .MISO(MISO), 
			.done(done), .rd_data(rd_data), 
			.MOSI(MOSI), .SCLK(SCLK), .SS_n(SS_n));

//3 enables determine which data we need to use
	always_ff @(posedge clk)
		if(en1 & update)
			lft_ld <= rd_data[11:0];

	always_ff @(posedge clk)
		if(en2 & update)
			rght_ld <= rd_data[11:0];

	always_ff @(posedge clk) 
		if(en3 & update)
			batt <= rd_data[11:0];
			
//state transition flop
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			rnd_cnt <= 0;
		else if(update & en3)
			rnd_cnt <= 0;
		else if(update)
			rnd_cnt <= rnd_cnt + 1; 
	end
	
//assign each enable to a specific round count
	assign en1 = ~|rnd_cnt;
	assign en2 = rnd_cnt == 1;
	assign en3 = rnd_cnt == 2;
	assign chnl = (~|rnd_cnt) ? 0:
			(rnd_cnt == 1) ? 4: 5;
	assign cmd = {2'b00, chnl[2:0], 11'h000};

//4 states. 1 with 2 send states with a dead state between. Dead state prevents overlapping data
	always_comb begin
		wrt = 0;
		update = 0;
		nxt_state = IDLE;
		case(state)
			IDLE: if(nxt) begin
				wrt = 1;
				nxt_state = SEND1;
			end
			SEND1: if(done)begin
				nxt_state = DEAD;
			end
			else begin
				nxt_state = SEND1;
			end
			DEAD: begin
				wrt = 1;
				nxt_state = SEND2;
			end
			SEND2:if(done) begin
				update = 1;
				nxt_state = IDLE;
			end 
			else begin
				nxt_state = SEND2;
			end
		endcase
	end
endmodule
