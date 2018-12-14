module inert_intf(clk, rst_n, vld, ptch, SS_n, SCLK, MOSI, MISO, INT);
//Define input and outputs and internal signals and states
output reg SS_n, SCLK, MOSI, vld;
output reg [15:0] ptch;
input clk, rst_n;
input MISO, INT;
//9 different states with unique states reading each pitch and azh
typedef enum reg [4:0] {INIT1, INIT2, INIT3, INIT4, READ_PITCHL, READ_PITCHH, READ_AZH, READ_AZL, READ_LAST} state_t;
state_t state, next_state; 
logic C_P_H, C_P_L, C_AZ_H, C_AZ_L;
logic [7:0] pitchL, pitchH, AZH, AZL;
logic [15:0] rd_data;
logic [15:0] cmd;
logic [15:0] timer;
logic [15:0] AZ, ptch_rt;
logic INT_ff1, INT_ff2;
logic wrt;
//Instantiate spi master and inertial integrator
SPI_mstr16 spi(.clk(clk), .rst_n(rst_n), .MISO(MISO), .MOSI(MOSI), .SCLK(SCLK), .SS_n(SS_n), .wrt(wrt), .cmd(cmd), .done(done), .rd_data(rd_data));

inertial_integrator integrator(.clk(clk), .rst_n(rst_n), .ptch_rt(ptch_rt),.AZ(AZ), .vld(vld), .ptch(ptch));

assign AZ = {AZH, AZL};
assign ptch_rt = {pitchH, pitchL};

//timer
always @(posedge clk, negedge rst_n)
	if (!rst_n) 	
		timer <= 16'b0;
	else 
		timer <= timer + 16'b1;

		//Double flop the INT for metastability purposes
always @(posedge clk, negedge rst_n)
	if(!rst_n) begin
		INT_ff1 <= 0;
		INT_ff2 <= 0;
	end
	else begin
		INT_ff1<=INT;
		INT_ff2<=INT_ff1;
	end
	
	//state transition flop
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= INIT1;
	else
		state <= next_state;

//Depending on the output signal, assign the read data to the specific register
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		pitchH <= 8'b0;
	else if (C_P_H)
		pitchH <= rd_data[7:0];


always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		AZH <= 8'b0;
	else if (C_AZ_H)
		AZH <= rd_data[7:0];

always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		AZL <= 8'b0;
	else if (C_AZ_L)
		AZL <= rd_data[7:0];


always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		pitchL <= 8'b0;
	else if (C_P_L)
		pitchL <= rd_data[7:0];

		//State machine that reads the command to determine which register to read to
always_comb begin
	C_P_H = 0;
	C_P_L = 0;
	C_AZ_H = 0;
	C_AZ_L = 0;
	cmd = 0;
	vld = 0;
	wrt = 0;
	case (state) 
	//4 initialization stages
		INIT1: begin
			cmd = 16'h0D02;
			if (&timer) begin
				next_state = INIT2;
				wrt = 1;
			end
			else 
				next_state = INIT1;
		end

		INIT2: begin
			cmd = 16'h1053;
			if (&timer[9:0]) begin
				wrt = 1;
				next_state = INIT3;
			end
			else 		
				next_state = INIT2;
		end

		INIT3: begin
			cmd = 16'h1150;
			if (&timer[9:0]) begin
				wrt = 1;
				next_state = INIT4;
			end
			else 
				next_state = INIT3;
		end
		
		INIT4: begin
			cmd = 16'h1460;
			if (&timer[9:0]) begin
				wrt = 1;
				next_state = READ_PITCHL;
			end
			else 
				next_state = INIT4;
		end
		//Read pitchl first
		READ_PITCHL: begin
			if (INT_ff2 && done) begin
				wrt = 1;
				cmd = 16'hA2xx;
				next_state = READ_PITCHH;
			end
			else
				next_state = READ_PITCHL;
		end
		//Sequentially read
		READ_PITCHH: begin
			if (done) begin
				wrt = 1;
				C_P_L = 1;
				cmd = 16'hA3xx;
				next_state = READ_AZL;
			end
			else
				next_state = READ_PITCHH;
		end
		READ_AZL: begin
			if (done) begin
				wrt = 1;
				C_P_H = 1;
				cmd = 16'hACxx;
				next_state = READ_AZH;
			end
			else
				next_state = READ_AZL;
		end
		READ_AZH: begin
			if (done) begin
				wrt = 1;
				C_AZ_L = 1;
				cmd = 16'hADxx;
				//vld = 1;
				next_state = READ_LAST;
			end
			else
				next_state = READ_AZH;
		end
		//Final read that reads C_AZ_H last
		READ_LAST: begin
			if (done) begin
				wrt = 1;
				C_AZ_H = 1; 
				vld = 1;
				next_state = READ_PITCHL;
			end
			else
				next_state = READ_LAST;
			end

		default: begin
			next_state = INIT1;
		end
	endcase
end

endmodule
 
