module mmm01 (
	input         enable,

	input         clk_sys,
	input         ce_cpu,

	input         savestate_load,
	input [63:0]  savestate_data,
	inout [63:0]  savestate_back_b,

	input         has_ram,
	input  [3:0]  ram_mask,
	input  [8:0]  rom_mask,

	input [14:0]  cart_addr,
	input         cart_a15,

	input  [7:0]  cart_mbc_type,

	input         cart_wr,
	input  [7:0]  cart_di,

	input  [7:0]  cram_di,
	inout  [7:0]  cram_do_b,
	inout [16:0]  cram_addr_b,

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

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 64'hZ;

// --------------------- CPU register interface ------------------
// https://wiki.tauwasser.eu/view/MMM01

reg [8:0] rom_bank_reg;
reg [3:0] ram_bank_reg;
reg [3:0] rom_bank_we_n_18_15;
reg [1:0] ram_bank_we_n_14_13;
reg ram_enable, map_en;
reg mbc1_mode, mbc1_mode_we_n;
reg rom_mux;

assign savestate_back[ 8: 0] = rom_bank_reg;
assign savestate_back[12: 9] = ram_bank_reg;
assign savestate_back[16:13] = rom_bank_we_n_18_15;
assign savestate_back[18:17] = ram_bank_we_n_14_13;
assign savestate_back[   19] = ram_enable;
assign savestate_back[   20] = map_en;
assign savestate_back[   21] = mbc1_mode;
assign savestate_back[   22] = mbc1_mode_we_n;
assign savestate_back[   23] = rom_mux;
assign savestate_back[63:24] = 0;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg        <= savestate_data[ 8: 0]; //9'd0;
		ram_bank_reg        <= savestate_data[12: 9]; //4'd0;
		rom_bank_we_n_18_15 <= savestate_data[16:13]; //4'd0;
		ram_bank_we_n_14_13 <= savestate_data[18:17]; //2'd0;
		ram_enable          <= savestate_data[   19]; //1'd0;
		map_en              <= savestate_data[   20]; //1'd0;
		mbc1_mode           <= savestate_data[   21]; //1'd0;
		mbc1_mode_we_n      <= savestate_data[   22]; //1'd0;
		rom_mux             <= savestate_data[   23]; //1'd0;
	end else if(~enable) begin
		rom_bank_reg        <= 9'd0;
		ram_bank_reg        <= 4'd0;
		rom_bank_we_n_18_15 <= 4'd0;
		ram_bank_we_n_14_13 <= 2'd0;
		ram_enable          <= 1'd0;
		map_en              <= 1'd0;
		mbc1_mode           <= 1'd0;
		mbc1_mode_we_n      <= 1'd0;
		rom_mux             <= 1'd0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_a15) begin
			case(cart_addr[14:13])
				2'b00: begin // 0x0000-0x1FFF: RAM Enable register
					ram_enable <= (cart_di[3:0] == 4'hA); // RAM enable/disable
					if (~map_en) begin
						ram_bank_we_n_14_13 <= cart_di[5:4]; // RAM bank #WE AA14-13 Low Active
						map_en <= cart_di[6];
					end
				end
				2'b01: begin // 0x2000-0x3FFF: ROM Bank register
					rom_bank_reg[0] <= cart_di[0]; // ROM bank RA14. Always writable
					if (~rom_bank_we_n_18_15[0]) rom_bank_reg[1] <= cart_di[1]; // ROM bank RA15
					if (~rom_bank_we_n_18_15[1]) rom_bank_reg[2] <= cart_di[2]; // ROM bank RA16
					if (~rom_bank_we_n_18_15[2]) rom_bank_reg[3] <= cart_di[3]; // ROM bank RA17
					if (~rom_bank_we_n_18_15[3]) rom_bank_reg[4] <= cart_di[4]; // ROM bank RA18
					if (~map_en) begin
						rom_bank_reg[6:5] <= cart_di[6:5]; // ROM bank RA20-19
					end
				end
				2'b10: begin // 0x4000-0x5FFF: RAM Bank register
					if (~ram_bank_we_n_14_13[0]) ram_bank_reg[0] <= cart_di[0]; // RAM bank AA13
					if (~ram_bank_we_n_14_13[1]) ram_bank_reg[1] <= cart_di[1]; // RAM bank AA14
					if (~map_en) begin
						 ram_bank_reg[3:2] <= cart_di[3:2]; // RAM bank AA16-15
						 rom_bank_reg[8:7] <= cart_di[5:4]; // ROM bank RA22-21
						 mbc1_mode_we_n <= cart_di[6]; // MBC1 Mode #WE Low Active
					end
				end
				2'b11: begin // 0x6000-0x7FFF: Mode register
					if (~mbc1_mode_we_n) mbc1_mode <= cart_di[0];
					if (~map_en) begin
						rom_bank_we_n_18_15 <= cart_di[5:2]; // ROM bank #WE Low active/Mask RA18-15
						rom_mux <= cart_di[6]; // Multiplexer for AA14-13 and RA20-RA19
					end
				end
			endcase
		end
	end
end

// MBC1 $6000 Mode register
wire [1:0] mbc1_bank2 = (~mbc1_mode & ~cart_addr[14]) ? 2'd0 : ram_bank_reg[1:0];

wire [3:0] ram_bank = { ram_bank_reg[3:2], (rom_mux ? rom_bank_reg[6:5] : mbc1_bank2) };

wire [4:0] rom_bank_low_m = { (rom_bank_reg[4:1] & ~rom_bank_we_n_18_15), rom_bank_reg[0] };

reg [8:0] rom_bank;
always @* begin
	rom_bank[8:7] = rom_bank_reg[8:7];
	rom_bank[6:5] = (rom_mux) ? mbc1_bank2 : rom_bank_reg[6:5];
	rom_bank[4:0] = rom_bank_reg[4:0];

	if (~cart_addr[14]) begin
		// 0x0000-0x3FFF = Bank 0. // Only unset bits allowed by mask
		rom_bank[4:1] = (rom_bank_reg[4:1] & rom_bank_we_n_18_15);
		rom_bank[  0] = 1'b0;
	end else if (rom_bank_low_m == 5'd0) begin
		// 0x4000-7FFF Bank 0=1
		rom_bank[0] = 1'b1;
	end

	// Fixed to last bank on boot
	if (~map_en) rom_bank[8:1] = 8'hFF;
end

// mask address lines to enable proper mirroring
wire [8:0] rom_bank_m = rom_bank & rom_mask; // 512
wire [3:0] ram_bank_m = ram_bank & ram_mask; // 16

assign mbc_addr = { rom_bank_m, cart_addr[13:0] };	// 16k ROM Bank 0-511
assign ram_enabled = ram_enable & has_ram;

assign cram_do = ram_enabled ? cram_di : 8'hFF;
// The only MMM01 cart with RAM is Momotarou Collection 2
// The game with saves is an MBC2 game so these are probably 512 byte banks.
assign cram_addr = { 4'd0, ram_bank_m, cart_addr[8:0] }; // 16x 512 bytes
assign has_battery = (cart_mbc_type == 8'h0D);


endmodule