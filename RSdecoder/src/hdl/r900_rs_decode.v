`timescale 1 ns/1 ps

module r900_rs_decode (
   clk, vld_in, dta_in, synd_in,/* k_in, rssi_in, bad_en,*/ pkt_vld, pkt_dta,/* pkt_rssi, pkt_k,*/ pkt_new, pkt_errors
);

input clk;
input vld_in;
input [104:0] dta_in;
input [24:0] synd_in;
//input [7:0] k_in;
//input [15:0] rssi_in;
//input bad_en;
output pkt_vld;
output [104:0] pkt_dta;
//output [15:0] pkt_rssi;
//output [7:0] pkt_k;
output pkt_new;
output [2:0] pkt_errors;

// syndromes for generator poly roots [a^2 a^1 a^0 a^-1 a^-2]
wire [24:0] log_synd_in;

// The logs of the syndromes are computed by table lookup.  The log(0) does
// not exist but the table contains the value 31 as a placeholder for log(0).
// gf_log = [31 0 1 18 2 5 19 11 3 29 6 27 20 8 12 23 4 10 30 17 7 22 28 26 21 25 9 16 13 14 24 15];

// log of syndrome for root a^-2
dist_mem_gen_1 gf_log_synd0 (
   .a(synd_in[4:0]),
   .spo(log_synd_in[4:0])
);

// log of syndrome for root a^-1
dist_mem_gen_1 gf_log_synd1 (
   .a(synd_in[9:5]),
   .spo(log_synd_in[9:5])
);

// log of syndrome for root a^0
dist_mem_gen_1 gf_log_synd2 (
   .a(synd_in[14:10]),
   .spo(log_synd_in[14:10])
);

// log of syndrome for root a^1
dist_mem_gen_1 gf_log_synd3 (
   .a(synd_in[19:15]),
   .spo(log_synd_in[19:15])
);

// log of syndrome for root a^2
dist_mem_gen_1 gf_log_synd4 (
   .a(synd_in[24:20]),
   .spo(log_synd_in[24:20])
);


reg vld_in_reg;
reg [104:0] dta_in_reg;
reg [24:0] synd_in_reg;
//reg [7:0] k_in_reg;
//reg [15:0] rssi_in_reg;
reg [24:0] log_synd_in_reg;

always @ (posedge clk)
begin
   if (vld_in)
   begin
      dta_in_reg <= dta_in;
      synd_in_reg <= synd_in;
//      k_in_reg <= k_in;
//      rssi_in_reg <= rssi_in;
      vld_in_reg <= 1'b1;
      log_synd_in_reg <= log_synd_in;
   end
   else
      vld_in_reg <= 1'b0;
end

wire [4:0]   log_synd0_in_reg = log_synd_in_reg[4:0];
wire [9:5]   log_synd1_in_reg = log_synd_in_reg[9:5];
wire [14:10] log_synd2_in_reg = log_synd_in_reg[14:10];
wire [19:15] log_synd3_in_reg = log_synd_in_reg[19:15];
wire [24:20] log_synd4_in_reg = log_synd_in_reg[24:20];


reg [3:0] vld_dly;

always @ (posedge clk)
begin
   vld_dly <= {vld_dly[2:0], vld_in_reg};
end

wire vld0 = vld_in_reg;
wire vld1 = vld_dly[0];
wire vld2 = vld_dly[1];
wire vld3 = vld_dly[2];
wire vld4 = vld_dly[3];


reg [104:0] dta_reg;
reg synd_all_zero, synd_any_zero, error; 
reg [4:0] log_synd_diff10, log_synd_diff21, log_synd_diff32, log_synd_diff43;

wire [4:0] err_pos = log_synd_diff43;
wire [4:0] err_mag = synd_in_reg[14:10];

always @ (posedge clk)
begin
   case (1'b1)
   vld0:
   begin
      dta_reg <= dta_in_reg;
      synd_all_zero <= (synd_in_reg[24:0] == 25'h0000000) ? 1'b1 : 1'b0;
      synd_any_zero <= (synd_in_reg[4:0] == 5'h00 || synd_in_reg[9:5] == 5'h00 || synd_in_reg[14:10] == 5'h00 || synd_in_reg[19:15] == 5'h00 || synd_in_reg[24:20] == 5'h00) ? 1'b1 : 1'b0;
      error <= 1'b0;
      log_synd_diff10 <= (log_synd1_in_reg < log_synd0_in_reg) ? (5'd31 + log_synd1_in_reg - log_synd0_in_reg) : (log_synd1_in_reg - log_synd0_in_reg);
      log_synd_diff21 <= (log_synd2_in_reg < log_synd1_in_reg) ? (5'd31 + log_synd2_in_reg - log_synd1_in_reg) : (log_synd2_in_reg - log_synd1_in_reg);
      log_synd_diff32 <= (log_synd3_in_reg < log_synd2_in_reg) ? (5'd31 + log_synd3_in_reg - log_synd2_in_reg) : (log_synd3_in_reg - log_synd2_in_reg);
      log_synd_diff43 <= (log_synd4_in_reg < log_synd3_in_reg) ? (5'd31 + log_synd4_in_reg - log_synd3_in_reg) : (log_synd4_in_reg - log_synd3_in_reg);  
   end

   vld1:
   begin
      if (!synd_any_zero && log_synd_diff10 == log_synd_diff21 && log_synd_diff21 == log_synd_diff32 && log_synd_diff32 == log_synd_diff43)
      begin
         case (err_pos)
            5'd0:  begin dta_reg[4:0]     <= dta_reg[4:0]     ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd1:  begin dta_reg[9:5]     <= dta_reg[9:5]     ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd2:  begin dta_reg[14:10]   <= dta_reg[14:10]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd3:  begin dta_reg[19:15]   <= dta_reg[19:15]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd4:  begin dta_reg[24:20]   <= dta_reg[24:20]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            // positions 5-14 are the shortened-code positions - they are invalid for corrections
            5'd15: begin dta_reg[29:25]   <= dta_reg[29:25]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd16: begin dta_reg[34:30]   <= dta_reg[34:30]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd17: begin dta_reg[39:35]   <= dta_reg[39:35]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd18: begin dta_reg[44:40]   <= dta_reg[44:40]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd19: begin dta_reg[49:45]   <= dta_reg[49:45]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd20: begin dta_reg[54:50]   <= dta_reg[54:50]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd21: begin dta_reg[59:55]   <= dta_reg[59:55]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd22: begin dta_reg[64:60]   <= dta_reg[64:60]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd23: begin dta_reg[69:65]   <= dta_reg[69:65]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd24: begin dta_reg[74:70]   <= dta_reg[74:70]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd25: begin dta_reg[79:75]   <= dta_reg[79:75]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd26: begin dta_reg[84:80]   <= dta_reg[84:80]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd27: begin dta_reg[89:85]   <= dta_reg[89:85]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd28: begin dta_reg[94:90]   <= dta_reg[94:90]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd29: begin dta_reg[99:95]   <= dta_reg[99:95]   ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            5'd30: begin dta_reg[104:100] <= dta_reg[104:100] ^ err_mag; synd_all_zero <= 1'b1; error <= 1'b1; end
            default: begin synd_all_zero <= 1'b0; end
         endcase
      end
   end
   endcase
end


reg pkt_vld, pkt_new;
reg [104:0] pkt_dta;
//reg [7:0] pkt_k;
//reg [15:0] pkt_rssi;
reg [2:0] pkt_errors;

always @ (posedge clk)
begin
   if (vld2 && (/*bad_en ||*/ synd_all_zero))
   begin
      pkt_dta <= dta_reg;
//     pkt_k <= k_in_reg;
//      pkt_rssi <= rssi_in_reg;
      pkt_errors <= synd_all_zero ? {2'b0, error} : 3'b111;
      pkt_new <= (dta_reg != pkt_dta); 
      pkt_vld <= 1'b1;
   end
   else
      pkt_vld <= 1'b0;
end

endmodule
