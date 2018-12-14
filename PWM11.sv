module PWM11(clk, rst_n, duty, PWM_sig);
//Assign inputs and outputs
input clk, rst_n;
input [10:0] duty;
output reg PWM_sig;

reg [10:0] cnt;
wire r, s;
//Pulse width modulation
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) 
		cnt <= 11'b0;
	else
		cnt <= cnt + 1;
end
//SR Flip Flop dependent on duty
assign s = (cnt == 11'b0) ? 1'b1 : 1'b0;
assign r = (cnt >= duty) ? 1'b1 : 1'b0;

always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		PWM_sig <= 1'b0;
	else if (r)
		PWM_sig <= 1'b0;
	else if (s)
		PWM_sig <= 1'b1;

end


endmodule
