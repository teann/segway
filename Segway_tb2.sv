Module Segway_tb2();
			
//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM_rev_rght, PWM_frwrd_rght, PWM_rev_lft, PWM_frwrd_lft;
wire piezo,piezo_n;

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] cmd;					// command host is sending to DUT
reg send_cmd;					// asserted to initiate sending of command
reg signed [15:0] rider_lean;	// forward/backward lean (goes to SegwayModel)


/////// declare any internal signals needed at this level //////
wire cmd_sent;
// internal signals for left right loads and battery
logic [11:0] ld_cell_lft, ld_cell_rght, batt_V;

////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Segway with Inertial sensor //
//////////////////////////////////////////////////////////////	
SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                  .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM_rev_rght(PWM_rev_rght),
				  .PWM_frwrd_rght(PWM_frwrd_rght),.PWM_rev_lft(PWM_rev_lft),
				  .PWM_frwrd_lft(PWM_frwrd_lft),.rider_lean(rider_lean));				  

/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
ADC128S ADC(.clk(clk), .ld_cell_lft(ld_cell_lft), .ld_cell_rght(ld_cell_rght), .batt_V(batt_V),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),.MISO(A2D_MISO),.MOSI(A2D_MOSI));
  
  
////// Instantiate DUT ////////
Segway iDUT(.clk(clk),.RST_n(RST_n),.LED(),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
            .INERT_SCLK(SCLK),.INERT_MISO(MISO),.A2D_SS_n(A2D_SS_n),
			.A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
			.INT(INT),.PWM_rev_rght(PWM_rev_rght),.PWM_frwrd_rght(PWM_frwrd_rght),
			.PWM_rev_lft(PWM_rev_lft),.PWM_frwrd_lft(PWM_frwrd_lft),
			.piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));


	
//// Instantiate UART_tx (mimics command from BLE module) //////
//// You need something to send the 'g' for go ////////////////
UART_tx iTX(.clk(clk),.rst_n(RST_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));
//Timeout condition
initial begin
 repeat(50000000) @(posedge clk);
 $stop();
end

initial begin
  clk = 0;
  RST_n = 1;
  @(posedge clk);
  init();	
  SendCmd(8'h67);
  Lean(16'h0F47);
  repeat(500) @(posedge clk);
  ld_cell_lft = 12'h300;
  ld_cell_rght = 12'h300;
  repeat(500) @(posedge clk);
  SendCmd(8'h73);
  repeat(20) @(posedge clk);
  if (iDUT.pwr_up == 0) begin//TEST CONDITION IF RIDER IS OFF AND STOP IS SENT
    $display("pwr_up should be asserted when rider is on but stop is sent");
  end
  repeat(100000) @(posedge clk);
  $display("YAHOO! test passed!");
  
  $stop();
end

always
  #10 clk = ~clk;

`include "tb_tasks.v"	// perhaps you have a separate included file that has handy tasks.

endmodule	
