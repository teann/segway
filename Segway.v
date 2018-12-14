module Segway(clk,RST_n,LED,INERT_SS_n,INERT_MOSI,
              INERT_SCLK,INERT_MISO,A2D_SS_n,A2D_MOSI,A2D_SCLK,
			  A2D_MISO,PWM_rev_rght,PWM_frwrd_rght,PWM_rev_lft,
			  PWM_frwrd_lft,piezo_n,piezo,INT,RX);
			  
  input clk,RST_n;
  input INERT_MISO;						// Serial in from inertial sensor
  input A2D_MISO;						// Serial in from A2D
  input INT;							// Interrupt from inertial indicating data ready
  input RX;								// UART input from BLE module

  
  output [7:0] LED;						// These are the 8 LEDs on the DE0, your choice what to do
  output A2D_SS_n, INERT_SS_n;			// Slave selects to A2D and inertial sensor
  output A2D_MOSI, INERT_MOSI;			// MOSI signals to A2D and inertial sensor
  output A2D_SCLK, INERT_SCLK;			// SCLK signals to A2D and inertial sensor
  output PWM_rev_rght, PWM_frwrd_rght;  // right motor speed controls
  output PWM_rev_lft, PWM_frwrd_lft;	// left motor speed controls
  output piezo_n,piezo;					// diff drive to piezo for sound
  
  ////////////////////////////////////////////////////////////////////////
  // fast_sim is asserted to speed up fullchip simulations.  Should be //
  // passed to both balance_cntrl and to steer_en.  Should be set to  //
  // 0 when we map to the DE0-Nano.                                  //
  ////////////////////////////////////////////////////////////////////
  localparam fast_sim = 1;	// asserted to speed up simulations. 
  
  ///////////////////////////////////////////////////////////
  ////// Internal interconnecting sigals defined here //////
  /////////////////////////////////////////////////////////
  wire rst_n;                           // internal global reset that goes to all units
  wire batt_low, ovr_spd, en_steer;
  wire [11:0] lft_ld, rght_ld, batt;
  wire vld;
  wire [15:0] ptch;
  wire pwr_up;
  wire [11:0] ld_cell_diff;
  wire [10:0] lft_spd, rght_spd;
  //assign LED = rght_spd[10:3];  DID NOT USE LED OUTPUTS ON DE0
  wire clr_tmr, tmr_full;
  reg [25:0] timer;
// Timer for balance control and steer enable
  always @(posedge clk, negedge rst_n)
	if (!rst_n)
		timer <= 0;
	else if (clr_tmr)
		timer <= 0;
	else
		timer <= timer + 1;

		//Depending on fast_sim, we go to a full timer or the first 15 digits of timer.
  assign tmr_full = (fast_sim) ? &timer[14:0] : &timer;

  ///////////////////////////////////////////////////////////
  ////// Inputs to Digital Core ////////////////////////////
  /////////////////////////////////////////////////////////

  //Inputs: RX, rider_off
  //Outputs: pwr_up
  //Receives data and makes sure the segway turns on
  Auth_blk auth_blk(.clk(clk), .rst_n(rst_n), .RX(RX), 
			.rider_off(rider_off), .pwr_up(pwr_up));


   //Inputs: nxt, MISO
   //Outputs: lft_ld, rght_ld, batt, SCLK, MOSI, SS_n
   //Takes signals from A2D convertor 
   A2D_Intf a2d_intf(.clk(clk), .rst_n(rst_n), .MISO(A2D_MISO), .nxt(vld), 
			.lft_ld(lft_ld), .rght_ld(rght_ld), .batt(batt), 
			.SCLK(A2D_SCLK), .MOSI(A2D_MOSI), .SS_n(A2D_SS_n));

   ///////////////////////////////////////////////////////////
   ////// Digital Core //////////////////////////////////////
   /////////////////////////////////////////////////////////

   //Inputs: pwr_up, vld, ptch, ld_cell_diff, rider_off, en_steer
   //Outputs: lft_spd, rght_spd, lft_rev, rght_rev, too_fast
   //HERE, WE HAVE FAST_SIM ON FOR SIMULATION PURPOSES
   balance_cntrl #(1) blnc_cntrl(.clk(clk),.rst_n(rst_n),.vld(vld),.ptch(ptch),
		.ld_cell_diff(ld_cell_diff),.lft_spd(lft_spd),
		.lft_rev(lft_rev),.rght_spd(rght_spd),
		.rght_rev(rght_rev),.rider_off(rider_off), 
		.en_steer(en_steer), .pwr_up(pwr_up), .too_fast(ovr_spd));

   //Inputs: lft_load, rght_load, tmr_full
   //Outputs: clr_tmr, rider_off, en_steer, too_fast
   //Controls steering and loads
   steer_en_SM #(1) steer_en(.clk(clk),.rst_n(rst_n), .tmr_full(tmr_full),.lft_ld(lft_ld), .rght_ld(rght_ld),
		.clr_tmr(clr_tmr),.en_steer(en_steer),.rider_off(rider_off));

   //Inputs: MISO, INT
   //Outputs: ptch, SS_n, SCLK, MOSI, vld
   //Inertial integrator interface. Transmits data between inertial integrator
   inert_intf inert_intf(.clk(clk), .rst_n(rst_n), .vld(vld), .ptch(ptch), 
			.SS_n(INERT_SS_n), .SCLK(INERT_SCLK), .MOSI(INERT_MOSI), .MISO(INERT_MISO), 
			.INT(INT));

   ///////////////////////////////////////////////////////////
   ////// Outputs of Digital Core ///////////////////////////
   /////////////////////////////////////////////////////////
   
   //Inputs: batt_low, ovr_spd, en_steer
   //Outputs: piezo, piezo_n 
   //Makes buzzer ~2 seconds for steer_en. Also buzzes if we are over speed or low battery
   piezo piezo_DUT(.batt_low(batt_low), .ovr_spd(ovr_spd), 
		.en_steer(en_steer), .clk(clk), .rst_n(rst_n), 
		.piezo(piezo), .piezo_n(piezo_n), .timer_2sec(timer[25]), .timer2_ensteer(timer[16]), .timer3_battspd(timer[14]));

   //Inputs: lft_spd, lft_rev,rght_spd, rght_rev
   //Outputs: PWM_rev_lft, PWM_frwrd_rght, PWM_frwrd_lft, PWM_rev_rght 
   //Combination logic that drives motor
   mtr_drv mtr_drv(.clk(clk), .rst_n(rst_n), .lft_spd(lft_spd), 
		.lft_rev(lft_rev), .PWM_rev_lft(PWM_rev_lft), 
		.PWM_frwrd_lft(PWM_frwrd_lft), .rght_spd(rght_spd), 
		.rght_rev(rght_rev), .PWM_rev_rght(PWM_rev_rght), 
		.PWM_frwrd_rght(PWM_frwrd_rght));
  

  /////////////////////////////////////
  // Instantiate reset synchronizer //
  ///////////////////////////////////  
  rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));

// ASSIGN LD_CELL_DIFF
  assign ld_cell_diff = lft_ld - rght_ld;
// BATTERY LOW THRESHOLD AT 0x800
  assign batt_low = batt < 12'h800;
  
endmodule
