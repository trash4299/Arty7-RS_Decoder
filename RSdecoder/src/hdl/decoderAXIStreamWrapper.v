`timescale 1ns / 1ps

module decoderAXIStreamWrapper (
    (* X_INTERFACE_PARAMETER = "CLK_DOMAIN <value>,PHASE 0.0,FREQ_HZ 100000000,LAYERED_METADATA undef,HAS_TLAST 1,HAS_TKEEP 1,HAS_TSTRB 0,HAS_TREADY 1,TUSER_WIDTH 0,TID_WIDTH 0,TDEST_WIDTH 0,TDATA_NUM_BYTES 8" *)
    input wire s_axis_aclk,
    input wire s_axis_aresetn,
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S2Dec TDATA" *)
	input [63:0] s_axis_tdata, // Transfer Data (optional)
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S2Dec TKEEP" *)
	input [7:0] s_axis_tkeep, // Transfer Null Byte Indicators (optional)
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S2Dec TLAST" *)
	input s_axis_tlast, // Packet Boundary Indicator (optional)
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S2Dec TREADY" *)
	output s_axis_tready, // Transfer ready (optional)
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S2Dec TVALID" *)
	input s_axis_tvalid, // Transfer valid (required)
		
	(* X_INTERFACE_PARAMETER = "CLK_DOMAIN <value>,PHASE 0.0,FREQ_HZ 100000000,LAYERED_METADATA undef,HAS_TLAST 1,HAS_TKEEP 1,HAS_TSTRB 0,HAS_TREADY 1,TUSER_WIDTH 0,TID_WIDTH 0,TDEST_WIDTH 0,TDATA_NUM_BYTES 8" *)
    input wire m_axis_aclk,
    input wire m_axis_aresetn,
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 Dec2S TDATA" *)
	output [63:0] m_axis_tdata, // Transfer Data (optional)
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 Dec2S TKEEP" *)
	output [7:0] m_axis_tkeep, // Transfer Null Byte Indicators (optional)
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 Dec2S TLAST" *)
	output m_axis_tlast, // Packet Boundary Indicator (optional)
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 Dec2S TREADY" *)
	input m_axis_tready, // Transfer ready (optional)
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 Dec2S TVALID" *)
	output m_axis_tvalid, // Transfer valid (required)
	
	
	//  additional ports here
	output reg vld_in = 0,
	output reg [104:0] dta_in = 105'd0,
	output reg [24:0] synd_in=25'd0,
	//output reg [7:0] k_in,
	//output reg [15:0] rssi_in,
	//output bad_en,
	input pkt_vld,
	input [104:0] pkt_dta,
	//input [15:0] pkt_rssi,
	//input [7:0] pkt_k,
	input pkt_new,
	input [2:0] pkt_errors
);
	
	reg [2:0] wr_ptr_reg = 3'd3, wr_ptr_next;
	reg [2:0] wr_addr_reg = 3'd3;
	reg [2:0] rd_ptr_reg = 3'd3, rd_ptr_next;
	reg [2:0] rd_addr_reg = 3'd3;

	reg s_rst_sync1_reg = 1'b1;
	reg s_rst_sync2_reg = 1'b1;
	reg s_rst_sync3_reg = 1'b1;
	reg m_rst_sync1_reg = 1'b1;
	reg m_rst_sync2_reg = 1'b1;
	reg m_rst_sync3_reg = 1'b1;
	reg [63:0] memIN[3:0];
	reg [63:0] memOUT[3:0];
	reg [63:0] mem_read_data_reg = 64'b0;
	reg mem_read_data_valid_reg = 1'b0, mem_read_data_valid_next;
	wire [63:0] mem_write_data;

	reg [63:0] m_data_reg = 64'b0;

	reg m_axis_tvalid_reg = 1'b0;
	wire m_axis_tvalid_next;
	reg vld_inreg;
	
	always@(*) begin
		vld_inreg <= memIN[3][32:32];
		dta_in[104:0] <= {memIN[2][36:32],memIN[2][28:24],memIN[2][20:16],memIN[2][12:8],memIN[2][4:0],memIN[1][60:56],memIN[1][52:48],
			memIN[1][44:40],memIN[1][36:32],memIN[1][28:24],memIN[1][20:16],memIN[1][12:8],memIN[1][4:0],memIN[0][60:56],memIN[0][52:48],
			memIN[0][44:40],memIN[0][36:32],memIN[0][28:24],memIN[0][20:16],memIN[0][12:8],memIN[0][4:0]};
		synd_in[24:0] <= {memIN[3][12:8],memIN[3][4:0],memIN[2][60:56],memIN[2][52:48],memIN[2][44:40]};
	end
	
	always@(posedge s_axis_aclk) begin
		if(vld_inreg) begin
			vld_in <= 1;
		end
		if(vld_in == 1) begin
			vld_in <= 0;
			vld_inreg <= 0;
			wr_ptr_reg <= 3'd0;
		end
	end
	
	reg pkt_vldreg = 0;
	always @(posedge m_axis_aclk) begin
		if(pkt_vld == 1) begin
			pkt_vldreg <= pkt_vld;
			{memOUT[0][63:0],memOUT[1][40:0]} <= pkt_dta;
			memOUT[3][1:1] <= pkt_new;
			memOUT[3][4:2] <= pkt_errors;
			rd_ptr_reg <= 3'd0;
		end
	end
	
	
	// full when ptr hits 3
	wire full = (wr_ptr_reg == 3'd4);
	// empty when ptr hits 3
	wire empty = (rd_ptr_reg == 3'd4);
	
	// control signals
	reg write, read, store_output;

	assign s_axis_tready = (~full & ~s_rst_sync3_reg);
	assign m_axis_tvalid_next = (~empty & ~m_rst_sync3_reg);
	
	assign m_axis_tvalid = m_axis_tvalid_reg;

	assign mem_write_data = s_axis_tdata;
	assign {m_axis_tlast, m_axis_tdata} = m_data_reg;

	// reset synchronization
	always @(posedge s_axis_aclk) begin
		if (!s_axis_aresetn) begin
			s_rst_sync1_reg <= 1'b1;
			s_rst_sync2_reg <= 1'b1;
			s_rst_sync3_reg <= 1'b1;
		end else begin
			s_rst_sync1_reg <= 1'b0;
			s_rst_sync2_reg <= s_rst_sync1_reg | m_rst_sync1_reg;
			s_rst_sync3_reg <= s_rst_sync2_reg;
		end
	end

	always @(posedge m_axis_aclk) begin
		if (!m_axis_aresetn) begin
			m_rst_sync1_reg <= 1'b1;
			m_rst_sync2_reg <= 1'b1;
			m_rst_sync3_reg <= 1'b1;
		end else begin
			m_rst_sync1_reg <= 1'b0;
			m_rst_sync2_reg <= s_rst_sync1_reg | m_rst_sync1_reg;
			m_rst_sync3_reg <= m_rst_sync2_reg;
		end
	end

	// Write logic   MM2Dec
	always @* begin
		write = 1'b0;
		wr_ptr_next = wr_ptr_reg;
		if (s_axis_tvalid) begin
			// input data valid
			if (~full) begin
				// not full, perform write
				write = 1'b1;
				wr_ptr_next = wr_ptr_reg + 1'b1;
			end
		end
	end

	always @(posedge s_axis_aclk) begin
		if (s_rst_sync3_reg) begin
			wr_ptr_reg <= 3'b0;
		end else begin
			wr_ptr_reg <= wr_ptr_next;
		end

		wr_addr_reg <= wr_ptr_next;

		if (write) begin
			memIN[wr_addr_reg[2:0]] <= mem_write_data;
		end
	end

	// Read logic    Dec2MM
	always @* begin
		read = 1'b0;

		rd_ptr_next = rd_ptr_reg;

		mem_read_data_valid_next = mem_read_data_valid_reg;

		if (store_output | ~mem_read_data_valid_reg) begin
			// output data not valid OR currently being transferred
			if (~empty&pkt_vldreg) begin
				// not empty, perform read and new packet avaliable
				read = 1'b1;
				mem_read_data_valid_next = 1'b1;
				rd_ptr_next = rd_ptr_reg + 1;
			end else begin
				// empty, invalidate
				if(pkt_vldreg) begin
					mem_read_data_valid_next = 1'b0;
					pkt_vldreg <= 0;
				end
			end
		end
	end

	always @(posedge m_axis_aclk) begin
		if (m_rst_sync3_reg) begin
			rd_ptr_reg <= 3'b0;
			mem_read_data_valid_reg <= 0;
			pkt_vldreg <= 0;
		end else begin
			rd_ptr_reg <= rd_ptr_next;
			mem_read_data_valid_reg <= mem_read_data_valid_next;
		end

		rd_addr_reg <= rd_ptr_next;

		if (read) begin
			mem_read_data_reg <= memOUT[rd_addr_reg[2:0]];
		end
	end

	// Output register
	always @* begin
		store_output = 1'b0;

		if (m_axis_tready | ~m_axis_tvalid) begin
			store_output = 1'b1;
		end
	end

	always @(posedge m_axis_aclk) begin
		if (m_rst_sync3_reg) begin
			m_axis_tvalid_reg <= 1'b0;
		end else begin
			m_axis_tvalid_reg <= m_axis_tvalid_next;
		end

		if (store_output) begin
			m_data_reg <= mem_read_data_reg;
		end
	end
endmodule
