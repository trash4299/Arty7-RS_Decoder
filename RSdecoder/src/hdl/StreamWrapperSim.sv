`timescale 1ns / 1ps
`define CLOCKTIME 100 //1000ns for 100MHz

module StreamWrapperSim();
    
    reg s_axis_aclk_tb = 0;
    reg s_axis_aresetn_tb = 0;
	reg [63:0] s_axis_tdata_tb = 64'd0; // Transfer Data (optional)
	reg [7:0] s_axis_tkeep_tb = 8'd0; // Transfer Null Byte Indicators (optional)
	reg s_axis_tlast_tb = 0; // Packet Boundary Indicator (optional)
	wire s_axis_tready_tb = 0; // Transfer ready (optional)
	reg s_axis_tvalid_tb = 0; // Transfer valid (required)
	
	reg m_axis_aclk_tb = 0;
    reg m_axis_aresetn_tb = 0;
	wire[63:0] m_axis_tdata_tb = 64'd0; // Transfer Data (optional)
	wire[7:0] m_axis_tkeep_tb = 8'd0; // Transfer Null Byte Indicators (optional)
	wire m_axis_tlast_tb = 0; // Packet Boundary Indicator (optional)
	reg m_axis_tready_tb = 0; // Transfer ready (optional)
	wire m_axis_tvalid_tb = 0; // Transfer valid (required)
	
	
	//  additional ports here
	wire vld_in_tb = 0;
	wire [104:0] dta_in_tb = 105'd0;
	wire [24:0] synd_in_tb = 25'd0;
	//wire [7:0] k_in_tb = 8'd0;
	//wire [15:0] rssi_in_tb = 16'd0;
	//wire bad_en_tb = 0;
	reg pkt_vld_tb = 0;
	reg [104:0] pkt_dta_tb = 105'd0;
	//reg [15:0] pkt_rssi_tb = 16'd0;
	//reg [7:0] pkt_k_tb = 8'd0;
	reg pkt_new_tb = 0;
	reg [2:0] pkt_errors_tb = 3'd0;
    
    always #`CLOCKTIME s_axis_aclk_tb <= ~s_axis_aclk_tb;
    always #`CLOCKTIME m_axis_aclk_tb <= ~m_axis_aclk_tb;
    
    decoderAXIStreamWrapper DUT(s_axis_aclk_tb,s_axis_aresetn_tb,s_axis_tdata_tb,s_axis_tkeep_tb,s_axis_tlast_tb,
		s_axis_tready_tb,s_axis_tvalid_tb,m_axis_aclk_tb,m_axis_aresetn_tb,m_axis_tdata_tb,m_axis_tkeep_tb,
		m_axis_tlast_tb,m_axis_tready_tb,m_axis_tvalid_tb,vld_in_tb,dta_in_tb,synd_in_tb,pkt_vld_tb,pkt_dta_tb,
		pkt_new_tb,pkt_errors_tb);
	
	initial begin
		#20000ns;
		$finish;
		
	end
endmodule
