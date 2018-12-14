module balance_cntrl(clk,rst_n,vld,ptch,ld_cell_diff,lft_spd,lft_rev,
                     rght_spd,rght_rev,rider_off, en_steer, pwr_up, too_fast);
								
  parameter fast_sim = 0;
  input clk,rst_n, pwr_up;
  input vld;						// tells when a new valid inertial reading ready
  input signed [15:0] ptch;			// actual pitch measured
  input signed [11:0] ld_cell_diff;	// lft_ld - rght_ld from steer_en block
  input rider_off;					// High when weight on load cells indicates no rider
  input en_steer;
  output [10:0] lft_spd;			// 11-bit unsigned speed at which to run left motor
  output lft_rev;					// direction to run left motor (1==>reverse)
  output [10:0] rght_spd;			// 11-bit unsigned speed at which to run right motor
  output rght_rev,too_fast;					// direction to run right motor (1==>reverse)
  
  ////////////////////////////////////
  // Define needed registers below //
  //////////////////////////////////
  logic signed [17:0] integrator;
  logic ov;
  logic signed [17:0] flop_input;
  logic signed [9:0] flop1_output;
  logic signed [9:0] prev_ptch_err; 
  logic signed [9:0] ptch_D_diff;
  logic signed [6:0] ptch_D_diff_sat;
  logic [15:0] lft_torque_abs_val;
  logic lft_selector; 
  logic signed [15:0] lft_multiply;
  logic signed [15:0] lft_alu;
  reg signed [15:0] lft_shaped;
  logic [15:0] lft_shaped_abs_val;
  logic [15:0] rght_torque_abs_val;
  logic rght_selector; 
  logic signed [15:0] rght_multiply;
  logic signed [15:0] rght_alu;
  reg signed [15:0] rght_shaped;
  logic [15:0] rght_shaped_abs_val;
  logic signed [15:0] PID_cntrl;
  logic signed [15:0] fast_sim_int;
  reg signed [15:0] lft_torque;
  reg signed [15:0] rght_torque;
  logic signed [15:0] ld_cell_diff_ext;

  ///////////////////////////////////////////
  // Define needed internal signals below //
  /////////////////////////////////////////
  wire signed [9:0] ptch_err_sat;
  reg signed [14:0] ptch_P_term;
  wire signed [17:0] ptch_err_sat_ex;
  wire signed [17:0] alu1;
  reg signed [12:0] ptch_D_term;
 
  /////////////////////////////////////////////
  // local params for increased flexibility //
  ///////////////////////////////////////////
  localparam P_COEFF = 5'h0E;
  localparam D_COEFF = 6'h14;				// D coefficient in PID control = +20 
  
    
  localparam LOW_TORQUE_BAND = 8'h46;	// LOW_TORQUE_BAND = 5*P_COEFF
  localparam GAIN_MULTIPLIER = 6'h0F;	// GAIN_MULTIPLIER = 1 + (MIN_DUTY/LOW_TORQUE_BAND)
  localparam MIN_DUTY = 15'h03D4;		// minimum duty cycle (stiffen motor and get it ready)
  //Use flops instead of combinational logic to reduce area
  always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		ptch_P_term <= 0;
	else
		ptch_P_term <= $signed(P_COEFF) * ptch_err_sat;
  
  always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		ptch_D_term <= 0;
	else
		ptch_D_term <= ptch_D_diff_sat * $signed(D_COEFF);
  // The P term of the PID
  // Signed multiply of COEFF with a 10 bit saturation in both positive and negative directions of ptch
  assign ptch_err_sat = ptch[15] ? (&ptch[14:9] ? ptch[9:0] : 10'b1000000000) : 
                                   (|ptch[14:9] ? 10'b0111111111 : ptch[9:0]);
  //assign nxt_ptch_P_term = $signed(P_COEFF) * ptch_err_sat;
// too_fast goes high if lft_spd or rght_spd exceeds 1536 (hazard conditions)
  assign too_fast = (lft_spd > 11'h600 || rght_spd > 11'h600);
  // The I of PID
  assign ptch_err_sat_ex = {{8{ptch_err_sat[9]}}, ptch_err_sat[9:0]}; // Sign extension
  assign alu1 = ptch_err_sat_ex + integrator;
  assign flop_input = rider_off ? 18'h00000 :  // Both muxes 
                      ((vld & ~ov) ? alu1 : integrator); // Flop input outputs a integrator term
  assign ov = (ptch_err_sat_ex[17] ~^ integrator[17]) & (ptch_err_sat_ex[17] ^ alu1[17]); 
	// Logic to implement ov which inspects MSBS of two numbers being added and if they match

  always @(posedge clk, negedge rst_n) begin // Always block inferring the flop of the integrator
    if (!rst_n) 
      integrator <= 18'h0;
    else if (!pwr_up)
      integrator <= 18'h0;
    else
      integrator <= flop_input;
  end

  // The D of PID
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      flop1_output <= 10'h0;
    else if (vld)
      flop1_output <= ptch_err_sat;
  end
// 2 flops back to back with muxes before
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      prev_ptch_err <= 18'h0;
    else if (vld) 
      prev_ptch_err <= flop1_output;
  end
// Subtraction alu with a saturation then a signed multiply
  assign ptch_D_diff = ptch_err_sat - prev_ptch_err;
  assign ptch_D_diff_sat = ptch_D_diff[9] ? (&ptch_D_diff[8:6] ? ptch_D_diff[6:0] : 7'b1000000) : (|ptch_D_diff[8:6] ? 7'b0111111 : ptch_D_diff[6:0]);
 // assign ptch_D_term = ptch_D_diff_sat * $signed(D_COEFF);
  
 //PID MATH GOES HERE... pretty much just follow the diagram
  // Balance cntrl cleanup, fast_sim_int speeds up integral term by 16x  
  assign fast_sim_int = fast_sim ? integrator[17:2] : {{4{integrator[17]}}, integrator[17:6]};
  assign PID_cntrl = {ptch_P_term[14], ptch_P_term[14:0]} 
					+ fast_sim_int
					+ {{3{ptch_D_term[12]}}, ptch_D_term[12:0]};
  assign ld_cell_diff_ext = {{7{ld_cell_diff[11]}}, ld_cell_diff[11:3]};
//  assign lft_torque = (en_steer) ? PID_cntrl - ld_cell_diff_ext: PID_cntrl;
//  assign rght_torque = (en_steer) ? PID_cntrl + ld_cell_diff_ext: PID_cntrl;

  always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		lft_torque <= 0;
	else if (en_steer)
		lft_torque <= PID_cntrl - ld_cell_diff_ext;
	else
		lft_torque <= PID_cntrl;
  
  always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		rght_torque <= 0;
	else if (en_steer)
		rght_torque <= PID_cntrl + ld_cell_diff_ext;
	else
		rght_torque <= PID_cntrl;
  
 // Torque shaping, likewise as abovem we follow the diagram on slide 11 of HW4

  //Left
  assign lft_torque_abs_val = lft_torque[15] ? ~lft_torque + 1 : lft_torque;
  assign lft_selector = lft_torque_abs_val >= LOW_TORQUE_BAND ? 1'b1 : 1'b0;
  assign lft_alu = lft_torque[15] ? (lft_torque - MIN_DUTY) : (lft_torque + MIN_DUTY);
  assign lft_multiply = lft_torque * GAIN_MULTIPLIER;
//  assign lft_shaped = lft_selector ? lft_alu : lft_multiply; 
  assign lft_rev = lft_shaped[15];
  assign lft_shaped_abs_val = lft_shaped[15] ? ~lft_shaped + 1 : lft_shaped;
//when pwr_up is high, only then can lft_spd an rght_spd be enabled
  assign lft_spd = pwr_up ? (|lft_shaped_abs_val[15:11] ? 11'b11111111111 : lft_shaped_abs_val[10:0]) : 11'h0;

  //Right side is same as left side.
  assign rght_torque_abs_val = rght_torque[15] ? ~rght_torque + 1 : rght_torque;
  assign rght_selector = rght_torque_abs_val >= LOW_TORQUE_BAND ? 1'b1 : 1'b0;
  assign rght_multiply = rght_torque * GAIN_MULTIPLIER;
  assign rght_alu = rght_torque[15] ? (rght_torque - MIN_DUTY) : (rght_torque + MIN_DUTY);
  //assign rght_shaped = rght_selector ? rght_alu : rght_multiply; 
  assign rght_rev = rght_shaped[15];
  assign rght_shaped_abs_val = rght_shaped[15] ? ~rght_shaped + 1 : rght_shaped;
  assign rght_spd = pwr_up ? (|rght_shaped_abs_val[15:11] ? 11'b11111111111 : rght_shaped_abs_val[10:0]) : 11'h0;
  //Instead of combinationally assigning lft and rght shaped, we use flops to reduce area
  always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		lft_shaped <= 0;
	else if (lft_selector)
		lft_shaped <= lft_alu;
	else
		lft_shaped <= lft_multiply;
  
  always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		rght_shaped <= 0;
	else if (lft_selector)
		rght_shaped <= rght_alu;
	else
		rght_shaped <= rght_multiply;
endmodule 
