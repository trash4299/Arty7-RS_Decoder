`timescale 1ns / 1ps
`define CLOCKTIME 100 //1000ns for 100MHz

module StreamWrapperSim();
    
    reg s_axis_aclk_tb = 0;
    reg s_axis_aresetn_tb = 1;
	reg [63:0] s_axis_tdata_tb = 64'd0; // Transfer Data (optional)
	reg [7:0] s_axis_tkeep_tb = 8'd0; // Transfer Null Byte Indicators (optional)
	reg s_axis_tlast_tb = 0; // Packet Boundary Indicator (optional)
	wire s_axis_tready_tb; // Transfer ready (optional)
	reg s_axis_tvalid_tb = 0; // Transfer valid (required)
	
	reg m_axis_aclk_tb = 0;
    reg m_axis_aresetn_tb = 1;
	wire[63:0] m_axis_tdata_tb; // Transfer Data (optional)
	wire[7:0] m_axis_tkeep_tb; // Transfer Null Byte Indicators (optional)
	wire m_axis_tlast_tb; // Packet Boundary Indicator (optional)
	reg m_axis_tready_tb = 0; // Transfer ready (optional)
	wire m_axis_tvalid_tb; // Transfer valid (required)
	
	
	//  additional ports here
	wire vld_in_tb;
	wire [104:0] dta_in_tb;
	wire [24:0] synd_in_tb;
	//wire [7:0] k_in_tb;
	//wire [15:0] rssi_in_tb;
	//wire bad_en_tb;
	wire pkt_vld_tb;
	wire [104:0] pkt_dta_tb;
	//reg [15:0] pkt_rssi_tb = 16'd0;
	//reg [7:0] pkt_k_tb = 8'd0;
	wire pkt_new_tb;
	wire [2:0] pkt_errors_tb;
    
    int state;
    
    always #`CLOCKTIME s_axis_aclk_tb <= ~s_axis_aclk_tb;
    always #`CLOCKTIME m_axis_aclk_tb <= ~m_axis_aclk_tb;
    
    decoderAXIStreamWrapper DUT(s_axis_aclk_tb,s_axis_aresetn_tb,s_axis_tdata_tb,s_axis_tkeep_tb,s_axis_tlast_tb,
		s_axis_tready_tb,s_axis_tvalid_tb,m_axis_aclk_tb,m_axis_aresetn_tb,m_axis_tdata_tb,m_axis_tkeep_tb,
		m_axis_tlast_tb,m_axis_tready_tb,m_axis_tvalid_tb,vld_in_tb,dta_in_tb,synd_in_tb,pkt_vld_tb,pkt_dta_tb,
		pkt_new_tb,pkt_errors_tb);
	// r900_rs_decode UUT(clk_tb, vld_in_tb, dta_in_tb, synd_in_tb,/* k_in_tb, rssi_in_tb, bad_en_tb,*/ pkt_vld_tb, 
		// pkt_dta_tb,/* pkt_rssi_tb, pkt_k_tb,*/ pkt_new_tb, pkt_errors_tb);
	
	initial begin
		state = 1;
		#5us;
		$finish;
	end
	
	always @(posedge s_axis_aclk_tb) begin
		case(state)
			1: begin
				if (s_axis_tready_tb) begin
					s_axis_tkeep_tb <= 8'hff;
					s_axis_tvalid_tb <= 1;
					s_axis_tdata_tb <= {3'd0,5'd8,3'd0,5'd7,3'd0,5'd6,3'd0,5'd5,3'd0,5'd4,3'd0,5'd3,3'd0,5'd2,3'd0,5'd1};
					state <= state + 1;
				end
				else begin
					s_axis_tkeep_tb <= 8'h0;
					s_axis_tvalid_tb <= 0;
				end
			end
			2: begin
				if (s_axis_tready_tb) begin
					s_axis_tkeep_tb <= 8'hff;
					s_axis_tvalid_tb <= 1;
					s_axis_tdata_tb <= {3'd0,5'd16,3'd0,5'd15,3'd0,5'd14,3'd0,5'd13,3'd0,5'd12,3'd0,5'd11,3'd0,5'd10,3'd0,5'd9};
					state <= state + 1;
				end
				else begin
					s_axis_tkeep_tb <= 8'h0;
					s_axis_tvalid_tb <= 0;
				end
			end
			3: begin 
				if (s_axis_tready_tb) begin
					s_axis_tkeep_tb <= 8'hff;
					s_axis_tvalid_tb <= 1;
					s_axis_tdata_tb <= {3'd0,5'd3,3'd0,5'd4,3'd0,5'd5,3'd0,5'd21,3'd0,5'd20,3'd0,5'd19,3'd0,5'd18,3'd0,5'd17};
					state <= state + 1;
				end
				else begin
					s_axis_tkeep_tb <= 8'h0;
					s_axis_tvalid_tb <= 0;
				end
			end
			4: begin 
				if (s_axis_tready_tb) begin
					s_axis_tkeep_tb <= 8'h1F;
					s_axis_tvalid_tb <= 1;
					s_axis_tdata_tb <= {8'd0,8'd0,8'd0,8'd1,8'd0,8'd0,3'd0,5'd1,3'd0,5'd2};
					s_axis_tlast_tb <= 1;
					state <= state + 1;
				end
				else begin
					s_axis_tkeep_tb <= 8'h0;
					s_axis_tvalid_tb <= 0;
				end
			end
			5: begin 
				s_axis_tlast_tb <= 0;
				s_axis_tkeep_tb <= 8'h0;
				s_axis_tvalid_tb <= 0;
				state <= state + 1;
			end
			6: begin 
				state <= state + 1;
			end
			7: begin 
				state <= state + 1;
			end
			8: begin 
				state <= state + 1;
			end
			9: begin 
				state <= state + 1;
			end
			10: begin 
				state <= state + 1;
			end
			11: begin 
				state <= state + 1;
			end
			12: begin 
				state <= state + 1;
			end
		endcase
	end
endmodule
