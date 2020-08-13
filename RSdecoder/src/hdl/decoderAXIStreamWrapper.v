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
	output reg vld_in,
	output reg [104:0] dta_in,
	output reg [24:0] synd_in,
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
	
	//assign bad_en = 0;
	reg pkt_vldreg = 0;
	reg [104:0] pkt_dtareg = 105'b0;
	reg pkt_newreg = 0;
	reg [2:0] pkt_errorsreg = 3'b0;
	
	always @(posedge m_axis_aclk) begin
		if(pkt_vld == 1) begin
			pkt_vldreg <= pkt_vld;
			pkt_dtareg <= pkt_dta;
			pkt_newreg <= pkt_new;
			pkt_errorsreg <= pkt_errors;
		end
	end
	
	reg [1:0] wr_ptr_reg = 2'b0, wr_ptr_next;
	reg [1:0] wr_addr_reg = 2'b0;
	reg [1:0] rd_ptr_reg = 2'b0, rd_ptr_next;
	reg [1:0] rd_addr_reg = 2'b0;

	reg s_rst_sync1_reg = 1'b1;
	reg s_rst_sync2_reg = 1'b1;
	reg s_rst_sync3_reg = 1'b1;
	reg m_rst_sync1_reg = 1'b1;
	reg m_rst_sync2_reg = 1'b1;
	reg m_rst_sync3_reg = 1'b1;
	
	// reg [64+2-1:0] mem[(2**32)-1:0];
	reg [63:0] memIN[3:0];
	reg [63:0] memOUT[3:0];
	reg [63:0] mem_read_data_reg = 64'b0;
	reg mem_read_data_valid_reg = 1'b0, mem_read_data_valid_next;
	wire [63:0] mem_write_data;

	reg [63:0] m_data_reg = 64'b0;

	reg m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
	
	always@(*) begin
		vld_in <= memIN[3][0:0];
		dta_in[104:0] <= {memIN[0][63:0],memIN[1][40:0]};
		synd_in[24:0] <= memIN[2][24:0];
//		k_in[7:0] <=  memIN[2][32:25];
//		rssi_in [15:0]  <=  memIN[2][48:33];
//		bad_en <=  memIN[3][49:49];
		pkt_vldreg <=  memOUT[3][0:0];
		pkt_dtareg[104:0]  <= {memOUT[0][63:0],memOUT[1][40:0]};
//		pkt_rssi[15:0]  <= memOUT[2][15:0];
//		pkt_k[7:0] <= memOUT[2][23:16];
		pkt_newreg <= memOUT[3][1:1];
		pkt_errorsreg[2:0]  <= memOUT[3][4:2];
	end

	// full when ptr hits 3
	wire full = (wr_ptr_reg == 2'd3);
	// empty when ptr hits 3
	wire empty = (rd_ptr_reg == 2'd3);

	// control signals
	reg write, read, store_output;

	assign s_axis_tready = ~full & ~s_rst_sync3_reg;

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
		
		if (s_axis_tvalid) begin
			// input data valid
			if (~full) begin			//I DONT THINK IT SHOULD NEED THIS BECAUSE DMA WILL ONLY SEND 4 PACKETS
				// not full, perform write
				write = 1'b1;
				wr_ptr_next = wr_ptr_reg + 1'b1;
			end
			else
				wr_ptr_next = 2'b0;
		end
	end

	always @(posedge s_axis_aclk) begin
		if (s_rst_sync3_reg) begin
			wr_ptr_reg <= 2'b0;
		end else begin
			wr_ptr_reg <= wr_ptr_next;
		end

		wr_addr_reg <= wr_ptr_next;

		if (write) begin
			memIN[wr_addr_reg[1:0]] <= mem_write_data;
		end
	end

	// pointer synchronization
	// always @(posedge s_axis_aclk) begin
		// if (s_rst_sync3_reg) begin
			// rd_ptr_gray_sync1_reg <= {32+1{1'b0}};
			// rd_ptr_gray_sync2_reg <= {32+1{1'b0}};
		// end else begin
			// rd_ptr_gray_sync1_reg <= rd_ptr_gray_reg;
			// rd_ptr_gray_sync2_reg <= rd_ptr_gray_sync1_reg;
		// end
	// end

	// always @(posedge m_axis_aclk) begin
		// if (m_rst_sync3_reg) begin
			// wr_ptr_gray_sync1_reg <= {32+1{1'b0}};
			// wr_ptr_gray_sync2_reg <= {32+1{1'b0}};
		// end else begin
			// wr_ptr_gray_sync1_reg <= wr_ptr_gray_reg;
			// wr_ptr_gray_sync2_reg <= wr_ptr_gray_sync1_reg;
		// end
	// end

	// Read logic    Dec2MM
	always @* begin
		read = 1'b0;

		rd_ptr_next = rd_ptr_reg;

		mem_read_data_valid_next = mem_read_data_valid_reg;

		if (store_output | ~mem_read_data_valid_reg) begin
			// output data not valid OR currently being transferred
			if (~empty&&memOUT[3][0]) begin
				// not empty, perform read and new packet avaliable
				read = 1'b1;
				mem_read_data_valid_next = 1'b1;
				rd_ptr_next = rd_ptr_reg + 1;
			end else begin
				// empty, invalidate
				mem_read_data_valid_next = 1'b0;
			end
		end
	end

	always @(posedge m_axis_aclk) begin
		if (m_rst_sync3_reg) begin
			rd_ptr_reg <= 2'b0;
			mem_read_data_valid_reg <= 1'b0;
		end else begin
			rd_ptr_reg <= rd_ptr_next;
			mem_read_data_valid_reg <= mem_read_data_valid_next;
		end

		rd_addr_reg <= rd_ptr_next;

		if (read) begin
			mem_read_data_reg <= memOUT[rd_addr_reg[1:0]];
		end
	end

	// Output register
	always @* begin
		store_output = 1'b0;

		m_axis_tvalid_next = m_axis_tvalid_reg;

		if (m_axis_tready | ~m_axis_tvalid) begin
			store_output = 1'b1;
			m_axis_tvalid_next = mem_read_data_valid_reg;
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