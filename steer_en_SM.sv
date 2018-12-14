module steer_en_SM(clk,rst_n, tmr_full,lft_ld, rght_ld,clr_tmr,en_steer,rider_off);

  input clk;				// 50MHz clock
  input rst_n;				// Active low asynch reset
  input tmr_full;		// asserted when timer reaches 1.3 sec
  logic sum_gt_min;			// asserted when left and right load cells together exceed min rider weight
  logic sum_lt_min;			// asserted when left_and right load cells are less than min_rider_weight
  input [11:0] lft_ld, rght_ld;
  parameter fast_sim = 0;
  logic [12:0] ld_sum;
  logic [25:0] timer;
  logic signed [15:0] fast_sim_int;
  logic diff_gt_1_4;		// asserted if load cell difference exceeds 1/4 sum (rider not situated)
  logic diff_gt_15_16;		// asserted if load cell difference is great (rider stepping off)
  output logic clr_tmr;		// clears the 1.3sec timer
  output logic en_steer;	// enables steering (goes to balance_cntrl)
  output logic rider_off;	// pulses high for one clock on transition back to initial state
  
  typedef enum reg [1:0] {IDLE, WAIT, STEER_EN} state_t; // 3 different states for our state machine. Wait is the "intermediate" stage before steer_en.
  state_t state, next_state;

/*assign fast_sim_int = fast_sim ? integrator[17:2] : {{4{integrator[17]}}, integrator[17:6]};
  assign PID_cntrl = {ptch_P_term[14], ptch_P_term[14:0]} 
					+ fast_sim_int
					+ {{3{ptch_D_term[12]}}, ptch_D_term[12:0]};*/
  localparam MIN_RIDER_WEIGHT = 12'h200;
  assign ld_sum  = lft_ld + rght_ld;
  assign sum_gt_min = (ld_sum >  MIN_RIDER_WEIGHT) ? 1 : 0;
  assign sum_lt_min = (ld_sum <  MIN_RIDER_WEIGHT) ? 1 : 0;
  assign diff_gt_1_4 = (lft_ld > rght_ld) ? ((lft_ld - rght_ld) > (ld_sum >> 2)) : ((rght_ld - lft_ld) > (ld_sum >> 2));
 // assign rider_off = (ld_sum <  MIN_RIDER_WEIGHT) ? 1 : 0;
  assign diff_gt_15_16 = (lft_ld > rght_ld) ? ((lft_ld - rght_ld) > (ld_sum - (ld_sum >> 4))) : ((rght_ld - lft_ld) > (ld_sum - (ld_sum >> 4)));

  always_ff @(posedge clk, negedge rst_n) begin // State transition flop
	if (!rst_n)
		state <= IDLE;
	else
		state <= next_state;
  end

  always_comb begin // Set signals to default 0
	clr_tmr = 0;
	en_steer = 0;
	rider_off = 0;
	next_state = IDLE;

  	case(state)
		IDLE: if (sum_gt_min) begin // If we get pass minimum weight, go high
			clr_tmr = 1'b1;
			next_state =  WAIT;
		end
		else
			rider_off = 1;
		
		WAIT: if (sum_lt_min) begin // If we're below minimum weight, get back to IDLE and our rider is OFF
			rider_off = 1'b1;
			next_state = IDLE;
		end
		else if (diff_gt_1_4) begin // If the difference between feet are too high, we set back to WAIT
			clr_tmr = 1'b1;
			next_state = WAIT;
		
		end
		else if (tmr_full) begin // If timer is full, we enable steering
			en_steer = 1'b1;
			next_state = STEER_EN;
		end
		else if (!diff_gt_1_4) begin // If we still have a weight difference issue, keep waiting
			next_state = WAIT;
		end
		
		STEER_EN: if (sum_lt_min) begin // We are below rider weight
			rider_off = 1'b1;
			next_state = IDLE;
		end
		else if (diff_gt_15_16) begin // The rider is stepping off, clear the timer and go into WAIT
			clr_tmr = 1'b1; 
			next_state = WAIT;
		end
		else if (!diff_gt_15_16) begin // Enable steering if the rider is not stepping off.
			en_steer = 1'b1;
			next_state = STEER_EN;
		end
		default: //Default state at idle
			next_state = IDLE;
		
	endcase
	end

			
endmodule