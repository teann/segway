module rst_synch(RST_n, clk, rst_n);

input clk, RST_n;
output reg rst_n; 
logic firstFlop;

//double flop the reset
always_ff @(negedge clk, negedge RST_n) begin
	if (!RST_n)
		firstFlop <= 1'b0;
	else
		firstFlop <= 1'b1;
end

always_ff @(negedge clk, negedge RST_n) begin
	if (!RST_n)
		rst_n <= 1'b0;
	else
		rst_n <= firstFlop;
end



endmodule