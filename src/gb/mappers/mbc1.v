module mbc1 (
	input         enable,
	input         mbc1m,

	input         clk_sys,
	input         ce_cpu,

	input         savestate_load,
	input [15:0]  savestate_data,
	inout [15:0]  savestate_back_b,

	input         has_ram,
	input  [1:0]  ram_mask,
	input  [6:0]  rom_mask,

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
wire [15:0] savestate_back;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 16'hZ;


// https://forums.nesdev.com/viewtopic.php?p=168940#p168940
// https://gekkio.fi/files/gb-docs/gbctr.pdf
// MBC1 $6000 Mode register:
// 0: Bank2 ANDed with CPU A14. Bank2 affects ROM 0x4000-0x7FFF only
// 1: Passthrough. Bank2 affects ROM 0x0000-0x3FFF, 0x4000-0x7FFF, RAM 0xA000-0xBFFF
wire [1:0] mbc1_bank2 = mbc_ram_bank_reg[1:0] & {2{cart_addr[14] | mbc1_mode}};


wire [1:0] mbc1_ram_bank = mbc1_bank2 & ram_mask[1:0];

// 0x0000-0x3FFF = Bank 0
wire [4:0] mbc_rom_bank = (~cart_addr[14]) ? 5'd0 : mbc_rom_bank_reg;

// MBC1: 4x32 16KByte banks, MBC1M: 4x16 16KByte banks
wire [6:0] mbc1_rom_bank_mode = mbc1m ? { 1'b0, mbc1_bank2, mbc_rom_bank[3:0] }
									  : {       mbc1_bank2, mbc_rom_bank[4:0] };

// mask address lines to enable proper mirroring
wire [6:0] mbc1_rom_bank = mbc1_rom_bank_mode & rom_mask[6:0];	 //128


// --------------------- CPU register interface ------------------
reg mbc_ram_enable;
reg mbc1_mode;
reg [4:0] mbc_rom_bank_reg;
reg [1:0] mbc_ram_bank_reg;

assign savestate_back[ 4: 0] = mbc_rom_bank_reg;
assign savestate_back[ 8: 5] = 0;
assign savestate_back[10: 9] = mbc_ram_bank_reg;
assign savestate_back[12:11] = 0;
assign savestate_back[   13] = mbc1_mode;
assign savestate_back[   14] = 0;
assign savestate_back[   15] = mbc_ram_enable;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		mbc_rom_bank_reg <= savestate_data[4 : 0]; //5'd1;
		mbc_ram_bank_reg <= savestate_data[10: 9]; //2'd0;
		mbc1_mode        <= savestate_data[   13]; //1'b0;
		mbc_ram_enable   <= savestate_data[   15]; //1'b0;
	end else if(~enable) begin
		mbc_rom_bank_reg <= 5'd1;
		mbc_ram_bank_reg <= 2'd0;
		mbc1_mode        <= 1'b0;
		mbc_ram_enable   <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_a15) begin
			case(cart_addr[14:13])
				2'b00: mbc_ram_enable <= (cart_di[3:0] == 4'ha); //RAM enable/disable
				2'b01: mbc_rom_bank_reg <= (cart_di[4:0] == 0) ? 5'd1 : cart_di[4:0]; //write to ROM bank register
				2'b10: mbc_ram_bank_reg <= cart_di[1:0]; //write to RAM bank register
				2'b11: mbc1_mode <= cart_di[0]; // MBC1 ROM/RAM Mode Select
			endcase
		end
	end
end

assign mbc_addr = { 2'b00, mbc1_rom_bank, cart_addr[13:0] };	// 16k ROM Bank 0-127 or MBC1M Bank 0-63
assign ram_enabled = mbc_ram_enable & has_ram;

assign cram_do = ram_enabled ? cram_di : 8'hFF;
assign cram_addr = { 2'b00, mbc1_ram_bank, cart_addr[12:0] };
assign has_battery = (cart_mbc_type == 8'h03);


endmodule