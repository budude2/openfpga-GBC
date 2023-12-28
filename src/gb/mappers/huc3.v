module huc3 (
	input         enable,

	input         clk_sys,
	input         ce_cpu,

	input         savestate_load,
	input [63:0]  savestate_data,
	inout [63:0]  savestate_back_b,

	input         ce_32k,
	input [32:0]  RTC_time,
	inout [31:0]  RTC_timestampOut_b,
	inout [47:0]  RTC_savedtimeOut_b,
	inout         RTC_inuse_b,

	input         bk_rtc_wr,
	input [16:0]  bk_addr,
	input [15:0]  bk_data,

	input         has_ram,
	input  [3:0]  ram_mask,
	input  [8:0]  rom_mask,

	input [14:0]  cart_addr,
	input         cart_a15,

	input  [7:0]  cart_mbc_type,

	input         cart_rd,
	input         cart_wr,
	input  [7:0]  cart_di,
	inout         cart_oe_b,

	input         nCS,

	input  [7:0]  cram_di,
	inout  [7:0]  cram_do_b,
	inout [16:0]  cram_addr_b,

	inout [22:0]  mbc_addr_b,
	inout         ram_enabled_b,
	inout         has_battery_b
);

wire [22:0] mbc_addr;
wire        ram_enabled;
wire  [7:0] cram_do;
wire [16:0] cram_addr;
wire        cart_oe;
wire        has_battery;
wire [63:0] savestate_back;

reg  [31:0] RTC_timestampOut;
reg  [47:0] RTC_savedtimeOut;
wire        RTC_inuse = 1;

wire        is_cram_addr = ~nCS & ~cart_addr[14];

assign mbc_addr_b         = enable ? mbc_addr         : 23'hZ;
assign cram_do_b          = enable ? cram_do          :  8'hZ;
assign cram_addr_b        = enable ? cram_addr        : 17'hZ;
assign cart_oe_b          = enable ? cart_oe          :  1'hZ;
assign ram_enabled_b      = enable ? ram_enabled      :  1'hZ;
assign has_battery_b      = enable ? has_battery      :  1'hZ;
assign savestate_back_b   = enable ? savestate_back   : 64'hZ;
assign RTC_timestampOut_b = enable ? RTC_timestampOut : 32'hZ;
assign RTC_savedtimeOut_b = enable ? RTC_savedtimeOut : 48'hZ;
assign RTC_inuse_b        = enable ? RTC_inuse        :  1'hZ;

// --------------------- CPU register interface ------------------

reg [6:0] rom_bank_reg;
reg [1:0] ram_bank_reg;
reg [3:0] mode;

assign savestate_back[ 6: 0] = rom_bank_reg;
assign savestate_back[ 8: 7] = ram_bank_reg;
assign savestate_back[12: 9] = mode;
assign savestate_back[63:13] = 0;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg <= savestate_data[ 6: 0]; // 7'd0;
		ram_bank_reg <= savestate_data[ 8: 7]; // 2'd0;
		mode         <= savestate_data[12: 9]; // 4'd0;
	end else if(~enable) begin
		rom_bank_reg <= 7'd0;
		ram_bank_reg <= 2'd0;
		mode         <= 4'd0;
	end else if(ce_cpu) begin
		if (cart_wr) begin
			if (~cart_a15) begin
				case(cart_addr[14:13])
					2'b00: mode <= cart_di[3:0];
					2'b01: rom_bank_reg <= cart_di[6:0]; // ROM bank register
					2'b10: ram_bank_reg <= cart_di[1:0]; // RAM bank register
					default: ;
				endcase
			end
		end
	end
end

reg [ 7:0] rtc_index;
reg [ 3:0] rtc_flags;
reg [ 3:0] rtc_out;
reg [ 5:0] rtc_seconds;
reg [14:0] rtc_subseconds;
reg [11:0] rtc_minutes; // Minutes of the day 0-1439
reg [15:0] rtc_days;

reg [31:0] RTC_timestampSaved;
reg [47:0] RTC_savedtimeIn;
reg        RTC_timestampNew_1;
reg        RTC_saveLoaded;

wire       rtc_subseconds_end = &rtc_subseconds;
reg [31:0] diffSeconds;
wire       diffSeconds_fast_count = (diffSeconds > 0);

always @(posedge clk_sys) begin
	if (ce_32k) rtc_subseconds <= rtc_subseconds + 1'b1;

	if (ce_32k & rtc_subseconds_end) begin
		RTC_timestampOut <= RTC_timestampOut + 1'd1;
	end else if (diffSeconds_fast_count) begin // fast counting loaded seconds
		diffSeconds	<= diffSeconds - 1'd1;
	end

	if ((ce_32k & rtc_subseconds_end) | diffSeconds_fast_count) begin
		rtc_seconds <= rtc_seconds + 1'b1;
		if (rtc_seconds == 59) begin
			rtc_seconds <= 0;
			rtc_minutes <= rtc_minutes + 1'b1;
			if (rtc_minutes == 1439) begin
				rtc_minutes <= 0;
				rtc_days <= rtc_days + 1'b1;
			end
		end
	end

	RTC_saveLoaded <= 1'b0;
	if (bk_rtc_wr) begin // load data from savefile to intermediate register
		case (bk_addr[7:0])
			0: RTC_timestampSaved[15:0]  <= bk_data;
			1: RTC_timestampSaved[31:16] <= bk_data;
			2: RTC_savedtimeIn[15:0]     <= bk_data;
			3: RTC_savedtimeIn[31:16]    <= bk_data;
			4: RTC_savedtimeIn[47:32]    <= bk_data;
			5: RTC_saveLoaded            <= 1'b1;
		endcase
	end

	if (RTC_saveLoaded) begin  // load data from intermediate register to RTC registers

		if (RTC_timestampOut > RTC_timestampSaved) begin
			diffSeconds <= RTC_timestampOut - RTC_timestampSaved;
		end

		rtc_seconds <= RTC_savedtimeIn[ 5: 0];
		rtc_minutes <= RTC_savedtimeIn[17: 6];
		rtc_days    <= RTC_savedtimeIn[33:18];
	end

	RTC_savedtimeOut[33: 0] <= { rtc_days, rtc_minutes, rtc_seconds };
	RTC_savedtimeOut[47:34] <= 0;

	if (~enable) begin
		rtc_index    <= 8'd0;
		rtc_flags    <= 4'd0;
		rtc_out      <= 4'd0;
	end else if(ce_cpu & cart_wr & is_cram_addr) begin // $A000-BFFF
		if (mode == 4'hB) begin
			if (cart_di[7:4] == 4'd1) begin
				case(rtc_index)
					8'h00: rtc_out <= rtc_minutes[ 3: 0];
					8'h01: rtc_out <= rtc_minutes[ 7: 4];
					8'h02: rtc_out <= rtc_minutes[11: 8];
					8'h03: rtc_out <= rtc_days[ 3: 0];
					8'h04: rtc_out <= rtc_days[ 7: 4];
					8'h05: rtc_out <= rtc_days[11: 8];
					8'h06: rtc_out <= rtc_days[15:12];
				endcase
				rtc_index <= rtc_index + 1'b1;
			end

			if (cart_di[7:4] == 4'd2 || cart_di[7:4] == 4'd3) begin
				case(rtc_index)
					8'h00: begin
						rtc_minutes[ 3: 0] <= cart_di[3:0];
						rtc_seconds        <= 0;
						rtc_subseconds     <= 0;
					end
					8'h01: rtc_minutes[ 7: 4] <= cart_di[3:0];
					8'h02: rtc_minutes[11: 8] <= cart_di[3:0];
					8'h03: rtc_days[ 3: 0]    <= cart_di[3:0];
					8'h04: rtc_days[ 7: 4]    <= cart_di[3:0];
					8'h05: rtc_days[11: 8]    <= cart_di[3:0];
					8'h06: rtc_days[15:12]    <= cart_di[3:0];
				endcase
				if (cart_di[4]) rtc_index <= rtc_index + 1'b1;
			end

			case(cart_di[7:4])
				4'd4: rtc_index[3:0] <= cart_di[3:0];
				4'd5: rtc_index[7:4] <= cart_di[3:0];
				4'd6: rtc_flags      <= cart_di[3:0];
				default: ;
			endcase
		end
	end

	RTC_timestampNew_1 <= RTC_time[32];  // saving timestamp from HPS
	if (RTC_timestampNew_1 != RTC_time[32]) begin
		RTC_timestampOut <= RTC_time[31:0];
	end

end

wire [1:0] ram_bank = ram_bank_reg & ram_mask[1:0];

// 0x0000-0x3FFF = Bank 0
wire [6:0] rom_bank = (~cart_addr[14]) ? 7'd0 : rom_bank_reg;

// mask address lines to enable proper mirroring
wire [6:0] rom_bank_m = rom_bank & rom_mask[6:0];	 //64

reg [7:0] cram_do_r;
always @* begin
	cram_do_r = 8'hFF;
	case(mode)
		// 0: RAM read, A: RAM read/write. Robopon reads from RAM with mode 0.
		4'h0, 4'hA: if (has_ram) cram_do_r = cram_di; // RAM
		4'hC: cram_do_r[3:0] = (rtc_flags == 4'd2) ? 4'h1 : rtc_out; // RTC
		4'hD: cram_do_r[3:0] = 4'h1; //RTC
		4'hE: cram_do_r[0] = 1'b0; // Light detected
		default: ;
	endcase
end

assign mbc_addr = { 2'b00, rom_bank_m, cart_addr[13:0] };	// 16k ROM Bank 0-127

assign cram_do = cram_do_r;
assign cram_addr = { 2'b00, ram_bank, cart_addr[12:0] };

assign cart_oe = cart_rd & (~cart_a15 | is_cram_addr);

assign ram_enabled = (mode == 4'hA) & has_ram; // RAM write enable
assign has_battery = has_ram;


endmodule