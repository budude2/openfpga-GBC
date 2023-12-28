module mbc2 (
	input        enable,

	input        clk_sys,
	input        ce_cpu,

	input        savestate_load,
	input [15:0] savestate_data,
	inout [15:0] savestate_back_b,

	input  [1:0] ram_mask,
	input  [6:0] rom_mask,

	input [14:0] cart_addr,
	input        cart_a15,

	input  [7:0] cart_mbc_type,

	input        cart_wr,
	input  [7:0] cart_di,

	input  [7:0] cram_di,
	inout  [7:0] cram_do_b,
	inout [16:0] cram_addr_b,

	inout [22:0] mbc_addr_b,
	inout        ram_enabled_b,
	inout        has_battery_b
);

wire [22:0] mbc_addr;
wire [7:0] cram_do;
wire [16:0] cram_addr;
wire ram_enabled;
wire has_battery;
wire [15:0] savestate_back;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 16'hZ;

// 0x0000-0x3FFF = Bank 0
wire [3:0] mbc_rom_bank = (~cart_addr[14]) ? 4'd0 : mbc_rom_bank_reg;

// mask address lines to enable proper mirroring
wire [3:0] mbc2_rom_bank = mbc_rom_bank & rom_mask[3:0];  //16


// --------------------- CPU register interface ------------------

reg [3:0] mbc_rom_bank_reg;
reg mbc_ram_enable;

assign savestate_back[ 3: 0] = mbc_rom_bank_reg;
assign savestate_back[14: 4] = 0;
assign savestate_back[   15] = mbc_ram_enable;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		mbc_rom_bank_reg <= savestate_data[3: 0]; //4'd1;
		mbc_ram_enable   <= savestate_data[  15]; //1'b0;
	end else if(~enable) begin
		mbc_rom_bank_reg <= 4'd1;
		mbc_ram_enable   <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_a15 & ~cart_addr[14]) begin
			if (cart_addr[8])
				mbc_rom_bank_reg <= (cart_di[3:0] == 4'd0) ? 4'd1 : cart_di[3:0]; //write to ROM bank register
			else
				mbc_ram_enable <= (cart_di[3:0] == 4'ha); //RAM enable/disable
		end
	end
end

assign mbc_addr = { 5'd0, mbc2_rom_bank, cart_addr[13:0] };	// 16k ROM Bank 0-15
assign cram_do = mbc_ram_enable ? { 4'hF,cram_di[3:0] } : 8'hFF; // 4 bit MBC2 Ram needs top half masked.
assign cram_addr = { 8'd0, cart_addr[8:0] }; // 512x4bits RAM built in MBC2
assign has_battery = (cart_mbc_type == 8'h06);
assign ram_enabled = mbc_ram_enable;

endmodule