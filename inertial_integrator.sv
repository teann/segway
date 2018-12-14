module inertial_integrator(clk, rst_n, vld, ptch_rt, AZ, ptch);
//Define inputs and outputs and internal signals
input clk, rst_n, vld;
input signed [15:0] ptch_rt;
input signed [15:0] AZ;
output signed [15:0] ptch;


reg signed [26:0] ptch_int;
logic signed [15:0] AZ_comp;
logic signed [15:0] ptch_rt_comp, ptch_acc;
logic signed [26:0] fusion_ptch_offset;
logic signed [25:0] ptch_acc_product;

//define localparams

localparam AZ_OFFSET = 16'hFE80;
localparam PTCH_RT_OFFSET = 16'h03C2;

//almost everything is signed here, but h147 is a fudge factor that lets us say that the pitch is proportional to AZ
assign ptch_acc_product = AZ_comp * $signed(10'h147);
assign ptch_acc = {{3{ptch_acc_product[25]}}, ptch_acc_product[25:13]};
assign ptch = ptch_int[26:11];
assign AZ_comp = AZ - AZ_OFFSET;
//here, we offset by 1024 or -1024 depending on if the ptch angle from acceleration compares to the ptch
assign fusion_ptch_offset = (ptch_acc > ptch) ? $signed(1024) : $signed(-1024);
assign ptch_rt_comp = ptch_rt - PTCH_RT_OFFSET;

// flip flop that concantenates the ptch_int
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n) 
		ptch_int <= 28'h0000;
	else if (vld)
		ptch_int <= ptch_int - {{11{ptch_rt_comp[15]}}, ptch_rt_comp} + fusion_ptch_offset;


endmodule