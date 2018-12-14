module PB_release(PB, rst_n, clk, released);

input PB, rst_n, clk;
output released;

logic firstFlop, secondFlop, thirdFlop;

always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		firstFlop <= 1'b1;
	else
		firstFlop <= PB;
end


always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		secondFlop <= 1'b1;
	else
		secondFlop <= firstFlop;
end



always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		thirdFlop <= 1'b1;
	else
		thirdFlop <= secondFlop;
end

assign released = secondFlop & ~thirdFlop;

endmodule
	