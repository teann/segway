module piezo(batt_low, ovr_spd, en_steer, clk, rst_n, piezo, piezo_n, timer_2sec, timer2_ensteer, timer3_battspd);
//Define internal signals and inputs and outputs
input batt_low, ovr_spd, en_steer, clk, rst_n, timer_2sec, timer2_ensteer, timer3_battspd;
output logic piezo, piezo_n;
logic [25:0] timer;

//Combinationally assign piezo depending on 3 timer signals to set en_steer beeping every 2 seconds at low freq
//High frequency beep at all times for ovr_spd or batt_low
assign piezo = (timer_2sec && en_steer) ? timer2_ensteer :
		(ovr_spd | batt_low) ? timer3_battspd : 0;

assign piezo_n = ~piezo;



endmodule
