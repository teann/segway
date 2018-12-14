module mtr_drv(clk, rst_n, lft_spd, lft_rev, PWM_rev_lft, PWM_frwrd_lft,
	 rght_spd, rght_rev, PWM_rev_rght, PWM_frwrd_rght);

input clk, rst_n, lft_rev, rght_rev; // lft_rev and rght_rev determine if the motor goes in reverse if high
input [10:0] lft_spd, rght_spd; // 11 bit duty cycle that tells the motor how fast to go

output PWM_rev_lft, PWM_frwrd_rght, PWM_frwrd_lft, PWM_rev_rght;
wire lft_mtr, rght_mtr;

PWM11 pwm11lft(.clk(clk), .rst_n(rst_n), .duty(lft_spd), .PWM_sig(lft_mtr));
PWM11 pwm11rght(.clk(clk), .rst_n(rst_n), .duty(rght_spd), .PWM_sig(rght_mtr)); // Take output of each module and and it with the lft_rev and rght_rev signals

assign PWM_frwrd_lft = (lft_mtr & ~lft_rev); // If lft_rev or rght_rev is low, we go FORWARD. Likewise in reverse.
assign PWM_frwrd_rght = (rght_mtr & ~rght_rev); // AND each rev signal and its negative with the resepective motor.
assign PWM_rev_lft = (lft_mtr & lft_rev);
assign PWM_rev_rght = (rght_mtr & rght_rev);

	
endmodule