module SPI_mstr16(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, cmd, done, rd_data);

input clk, rst_n, wrt;
input [15:0] cmd;
input MISO;

output logic done, MOSI, SCLK, SS_n; 
output [15:0] rd_data;

//Intermediate sampling, shifting, and sclk definitions
logic init, sclk_rise, sclk_fall;
logic rst_cnt, smpl, shft;
logic [15:0] shft_reg;
logic MISO_smpl;
logic [4:0] sclk_div;
logic set_done;
logic clr_done;
logic [3:0] shft_cnt;

//Four states: idle, active, and 2 porches to eliminate the edge cases
typedef enum reg [1:0] {IDLE, FRONT_PORCH, BACK_PORCH, ACTIVE} state_t;

state_t state, next_state;

// Dataflow to get SCLK and MOSI
assign SCLK = sclk_div[4];
assign MOSI = shft_reg[15];
assign rd_data = shft_reg;

// Counter for SCLK
always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
		sclk_div <= 5'b10111;   
	else if (rst_cnt)
		sclk_div <= 5'b10111;
	else 
		sclk_div <= sclk_div + 1;
end


//Makes the code more readable by defining a sclk rise and fall
assign sclk_rise = (sclk_div == 5'b01111) ? 1'b1 : 1'b0;
assign sclk_fall = (sclk_div == 5'b11111) ? 1'b1 : 1'b0;

//sample on smpl
always_ff @(posedge clk) begin
	if (smpl)
		MISO_smpl <= MISO;
end

// We use init here instead of wrt because we used init as an output of SM
always_ff @(posedge clk) begin
	if (init)
		shft_reg <= cmd;
	else if (shft)
		shft_reg <= {shft_reg[14:0], MISO_smpl};
end


always_ff @(posedge clk) // If we're shifting, increment shft_cnt. 
	if (init) begin //No reset necessary. When init goes high, we flip to 0.
		shft_cnt <= 4'b0;
	end
	else if (shft) begin
		shft_cnt <= shft_cnt + 1;
	end

			
always_ff @(posedge clk, negedge rst_n) // State transition flop
	if (!rst_n)
		state <= IDLE;
	else
		state <= next_state;


always_comb begin
	rst_cnt = 0; //Default statements
	smpl = 0;
	shft = 0;
	set_done = 0;
	clr_done = 0;
	init = 0;
	next_state = IDLE;
	case (state)
		IDLE:begin 
			rst_cnt = 1;
 			if (wrt) begin // We never sample and shift at same time
				clr_done = 1;
				init = 1;
				next_state = FRONT_PORCH;
			end
		end
		FRONT_PORCH: if (sclk_div == 5'b01111) begin
			smpl = 1; 

			next_state = ACTIVE;
		end
		else begin
			next_state = FRONT_PORCH;	
		end
		ACTIVE: if (sclk_rise && shft_cnt == 4'b1111) begin //before we go into back porch, sample.
			smpl = 1;
			next_state = BACK_PORCH;
		end
		else if (sclk_rise) begin
			smpl = 1;
			next_state = ACTIVE;
		end
		else if (sclk_fall) begin
			shft = 1; 
			next_state = ACTIVE;
		end
		else begin 
			next_state = ACTIVE;
		end
		BACK_PORCH: if (sclk_div == 5'b11111) begin  // Back porch (on sclk fall) means we shft and go back to idle, resetting the count and setting done
			shft = 1;
			set_done = 1;
			rst_cnt = 1;
			next_state = IDLE;
		end
		else begin
			next_state = BACK_PORCH;
		end
	endcase
end


// A set and preset SR flip flop to give us SS_n and done
always_ff @(posedge clk, negedge rst_n) 
	if (!rst_n)
		SS_n <= 1'b1;
	else if (set_done)
		SS_n <= 1'b1;
	else if (clr_done)
		SS_n <= 1'b0;
				
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		done <= 1'b0;
	else if (set_done)
		done <= 1'b1;
	else if (clr_done)
		done <= 1'b0;

endmodule

