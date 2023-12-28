module tama (
	input         enable,

	input         clk_sys,
	input         ce_cpu,
	input         ce_32k,

	input         savestate_load,
	input [63:0]  savestate_data,
	inout [63:0]  savestate_back_b,

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

	input         cram_rd,
	input  [7:0]  cram_di,
	inout  [7:0]  cram_do_b,
	inout [16:0]  cram_addr_b,

	inout         cram_wr_b,
	inout   [7:0] cram_wr_do_b,

	inout [22:0]  mbc_addr_b,
	inout         ram_enabled_b,
	inout         has_battery_b
);

wire [22:0] mbc_addr;
wire ram_enabled;
wire [7:0] cram_do;
wire [16:0] cram_addr;
wire has_battery;
wire [63:0] savestate_back;
wire [7:0] cram_wr_do;
wire cram_wr;
wire cart_oe;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 64'hZ;
assign cram_wr_do_b     = enable ? cram_wr_do     :  8'hZ;
assign cram_wr_b        = enable ? cram_wr        :  1'hZ;
assign cart_oe_b        = enable ? cart_oe        :  1'hZ;

// --------------------- CPU register interface ------------------
// https://gbdev.gg8.se/forums/viewtopic.php?id=469

reg unlocked;
reg [3:0] reg_index;
reg [4:0] rom_bank_reg;
reg [7:0] reg_data_in, reg_data_out;
reg [4:0] reg_addr;
reg ram_read; // 0: write, 1: read
reg [1:0] rtc_sel;
reg reg_start;
reg cram_wr_r;
reg ram_io;
reg prev_cram_rd;

reg [6:0] rtc_seconds;
reg [14:0] rtc_subseconds;
reg [6:0] rtc_minutes;
reg [5:0] rtc_hours;
reg [5:0] rtc_days;
reg [4:0] rtc_month;
reg [7:0] rtc_year;
reg       rtc_24hours;
reg [3:0] rtc_index;
reg [1:0] rtc_leap_year;

wire sec_inc = &rtc_subseconds;

reg [5:0] days_in_month;
always @* begin
	case(rtc_month)
		5'h4, 5'h6, 5'h9, 5'h11: days_in_month = 6'h30;
		5'h2: days_in_month = (rtc_leap_year == 2'b00) ? 6'h29 : 6'h28;
		default: days_in_month = 6'h31;
	endcase
end

assign savestate_back[ 4: 0] = rom_bank_reg;
assign savestate_back[    5] = unlocked;
assign savestate_back[ 9: 6] = reg_index;
assign savestate_back[17:10] = reg_data_in;
assign savestate_back[25:18] = reg_data_out;
assign savestate_back[30:26] = reg_addr;
assign savestate_back[   31] = ram_read;
assign savestate_back[33:32] = rtc_sel;
assign savestate_back[   34] = reg_start;
assign savestate_back[   35] = cram_wr_r;
assign savestate_back[   36] = ram_io;
assign savestate_back[   37] = prev_cram_rd;
assign savestate_back[63:38] = 0;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg <= savestate_data[ 4: 0]; //5'd0;
		unlocked     <= savestate_data[    5]; //1'd0;
		reg_index    <= savestate_data[ 9: 6]; //4'd0;
		reg_data_in  <= savestate_data[17:10]; //8'd0;
		reg_data_out <= savestate_data[25:18]; //8'd0;
		reg_addr     <= savestate_data[30:26]; //5'd0;
		ram_read     <= savestate_data[   31]; //1'd0;
		rtc_sel      <= savestate_data[33:32]; //2'd0;
		reg_start    <= savestate_data[   34]; //1'd0;
		cram_wr_r    <= savestate_data[   35]; //1'd0;
		ram_io       <= savestate_data[   36]; //1'd0;
		prev_cram_rd <= savestate_data[   37]; //1'd0;
	end else if(~enable) begin
		rom_bank_reg <= 5'd0;
		unlocked     <= 1'd0;
		reg_index    <= 4'd0;
		reg_data_in  <= 8'd0;
		reg_data_out <= 8'd0;
		reg_addr     <= 5'd0;
		ram_read     <= 1'd0;
		rtc_sel      <= 2'd0;
		reg_start    <= 1'd0;
		cram_wr_r    <= 1'd0;
		ram_io       <= 1'd0;
		prev_cram_rd <= 1'd0;
	end else begin

		if (ce_cpu & cart_wr & ~nCS & ~cart_addr[14]) begin // $A000-BFFF
			if (cart_addr[0]) begin
				reg_index <= cart_di[3:0]; // Register index
				if (cart_di[3:0] == 4'hA) begin
					unlocked <= 1'b1;
				end
			end else if (unlocked) begin
				case (reg_index)
					4'd0: rom_bank_reg[3:0] <= cart_di[3:0];
					4'd1: rom_bank_reg[4]   <= cart_di[0];
					4'd4: reg_data_in[3:0]  <= cart_di[3:0];
					4'd5: reg_data_in[7:4]  <= cart_di[3:0];
					4'd6: { rtc_sel, ram_read, reg_addr[4] } <= cart_di[3:0];
					4'd7:  begin
							reg_addr[3:0] <= cart_di[3:0];
							reg_start <= 1'b1;
						  end
					default ;
				endcase
			end
		end

        // TODO: Get RTC working. How does the game use the RTC?
        // The in game timer runs at ~16x speed so 1 minute passes every 3.75 seconds.
        // Does the RTC also run 16x speed or only when the Game Boy is on?
		if (ce_32k) begin
			rtc_subseconds <= rtc_subseconds + 1'b1;
			if (sec_inc) begin
				rtc_seconds[3:0] <= rtc_seconds[3:0] + 1'b1;
				if (rtc_seconds[3:0] == 4'h9) begin
					rtc_seconds[3:0] <= 0;
					rtc_seconds[6:4] <= rtc_seconds[6:4] + 1'b1;
					if (rtc_seconds[6:4] == 3'h5) begin
						rtc_seconds[6:4] <= 0;
						rtc_minutes[3:0] <= rtc_minutes[3:0] + 1'b1;
						if (rtc_minutes[3:0] == 4'h9) begin
							rtc_minutes[3:0] <= 0;
							rtc_minutes[6:4] <= rtc_minutes[6:4] + 1'b1;
							if (rtc_minutes[6:4] == 3'h5) begin
								rtc_minutes[6:4] <= 0;
								rtc_hours[3:0] <= rtc_hours[3:0] + 1'b1;
								if (rtc_24hours & rtc_hours[5:0] == 6'h23) begin // 23:59
									rtc_hours[5:0] <= 0;
								end else if (~rtc_24hours & rtc_hours[4:0] == 5'h12) begin // 12:59
									rtc_hours[4:0] <= 5'h1;
								end else if (rtc_hours[3:0] == 4'h9) begin // 9:59
									rtc_hours[3:0] <= 0;
									rtc_hours[5:4] <= rtc_hours[5:4] + 1'b1;
								end
								if (~rtc_24hours & rtc_hours[4:0] == 5'h11) begin // 11:59
									rtc_hours[5] <= ~rtc_hours[5]; // AM/PM
								end
								if ( (rtc_24hours & rtc_hours[5:0] == 6'h23)
										|| (~rtc_24hours & rtc_hours[5] & rtc_hours[4:0] == 5'h11) )
								begin
									rtc_days[3:0] <= rtc_days[3:0] + 1'b1;
									if (rtc_days[3:0] == 4'h9) begin
										rtc_days[3:0] <= 0;
										rtc_days[5:4] <= rtc_days[5:4] + 1'b1;
									end
									if (rtc_days[5:0] == days_in_month) begin
										rtc_days <= 6'h1;
										rtc_month[3:0] <= rtc_month[3:0] + 1'b1;
										if (rtc_month[3:0] == 4'h9) begin
											rtc_month[3:0] <= 0;
											rtc_month[4] <= rtc_month[4] + 1'b1;
										end
										if (rtc_month == 5'h12) begin
											rtc_month <= 5'h1;
											rtc_year[3:0] <= rtc_year[3:0] + 1'b1;
											rtc_leap_year <= rtc_leap_year + 1'b1;
											if (rtc_year[3:0] == 4'h9) begin
												rtc_year[3:0] <= 0;
												rtc_year[7:4] <= rtc_year[7:4] + 1'b1;
												if (rtc_year[7:4] == 4'h9) begin
													rtc_year[7:4] <= 0;
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end

		if (ce_cpu) begin
			cram_wr_r <= 0;
			ram_io <= 0;
			if (reg_start) begin
				reg_start <= 0;

				if (|rtc_sel) begin // RTC
					if (rtc_sel == 2'd1) begin
						case (reg_addr)
							5'h04: begin
									rtc_minutes <= reg_data_in[6:0];
									rtc_seconds <= 0;
									rtc_subseconds <= 0;
								   end
							5'h05: rtc_hours   <= reg_data_in[5:0];
							5'h06: rtc_index   <= 0;
							default: ;
						endcase
					end

					if (rtc_sel == 2'd2) begin
						case ({reg_addr,reg_data_in[3:0]})
							{2'd0, 4'h7}: rtc_days[3:0]  <= reg_data_in[7:4];
							{2'd0, 4'h8}: rtc_days[5:4]  <= reg_data_in[5:4];
							{2'd0, 4'h9}: rtc_month[3:0] <= reg_data_in[7:4];
							{2'd0, 4'hA}: rtc_month[4]   <= reg_data_in[4];
							{2'd0, 4'hB}: rtc_year[3:0]  <= reg_data_in[7:4];
							{2'd0, 4'hC}: rtc_year[7:4]  <= reg_data_in[7:4];

							{2'd2, 4'hA}: rtc_24hours    <= reg_data_in[4];
							{2'd2, 4'hB}: rtc_leap_year  <= reg_data_in[5:4];
							default: ;
						endcase
					end

				end else begin // RAM
					cram_wr_r <= ~ram_read;
					ram_io <= 1;
				end
			end

			if (ram_io & ram_read) begin
				reg_data_out <= cram_di;
			end

			prev_cram_rd <= cram_rd;
			if (prev_cram_rd & ~cram_rd & ~cart_addr[0] & |rtc_sel & reg_index[3:1] == 3'b110) begin
				rtc_index <= rtc_index + 1'b1;
			end
		end
	end
end

// 0x0000-0x3FFF = Bank 0
wire [4:0] rom_bank = (~cart_addr[14]) ? 5'd0 : rom_bank_reg;

// mask address lines to enable proper mirroring
wire [4:0] rom_bank_m = rom_bank & rom_mask[4:0];	 //32

assign mbc_addr = { 4'b0000, rom_bank_m, cart_addr[13:0] };	// 16k ROM Bank 0-31

reg [3:0] rtc_do_r;
always @* begin
	rtc_do_r = 4'h0;
	case(rtc_index)
		4'h0: rtc_do_r[3:0] = rtc_minutes[3:0];
		4'h1: rtc_do_r[2:0] = rtc_minutes[6:4];
		4'h2: rtc_do_r[3:0] = rtc_hours[3:0];
		4'h3: rtc_do_r[1:0] = rtc_hours[5:4];
		4'h4: rtc_do_r[3:0] = rtc_days[3:0];
		4'h5: rtc_do_r[1:0] = rtc_days[5:4];
		4'h6: rtc_do_r[3:0] = rtc_month[3:0];
		4'h7: rtc_do_r[0]   = rtc_month[4];
		//4'h8: rtc_do_r[3:0] = rtc_year[3:0]; Year?
		//4'h9: rtc_do_r[3:0] = rtc_year[7:4];
		default: ;
	endcase
end

reg [3:0] cram_do_r;
always @* begin
	cram_do_r = 4'hF;
	if (~cart_addr[0]) begin
		if (~unlocked) begin
			cram_do_r = 4'd0;
		end else
			case(reg_index)
				4'hA: cram_do_r = 4'd1;
				4'hC: cram_do_r = (|rtc_sel) ? rtc_do_r : reg_data_out[3:0]; // Data out low
				4'hD: cram_do_r = (|rtc_sel) ? rtc_do_r : reg_data_out[7:4]; // Data out high
				default: ;
			endcase
	end
end

assign cram_wr = cram_wr_r;
assign cram_wr_do = reg_data_in;

assign cram_do = { 4'hF, cram_do_r };
assign cram_addr = { 12'd0, reg_addr };

assign cart_oe = (cart_rd & ~cart_a15) | (cram_rd & ~cart_addr[0]);

assign has_battery = 1;
assign ram_enabled = 0;

endmodule