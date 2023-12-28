module mbc5 (
	input        enable,

	input        clk_sys,
	input        ce_cpu,

	input        savestate_load,
	input [15:0] savestate_data,
	inout [15:0] savestate_back_b,

	input        has_ram,
	input  [3:0] ram_mask,
	input  [8:0] rom_mask,

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
	inout        has_battery_b,
	output       rumbling
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
assign rumbling         = mbc_ram_bank_reg[3];

wire [3:0] mbc5_ram_bank = mbc_ram_bank_reg & ram_mask;

// 0x0000-0x3FFF = Bank 0
wire [8:0] mbc_rom_bank = (~cart_addr[14]) ? 9'd0 : mbc_rom_bank_reg;

// mask address lines to enable proper mirroring
wire [8:0] mbc5_rom_bank = mbc_rom_bank & rom_mask;  //480


// --------------------- CPU register interface ------------------

reg [8:0] mbc_rom_bank_reg;
reg [3:0] mbc_ram_bank_reg;
reg mbc_ram_enable;

assign savestate_back[ 8: 0] = mbc_rom_bank_reg;
assign savestate_back[12: 9] = mbc_ram_bank_reg;
assign savestate_back[14:13] = 0;
assign savestate_back[   15] = mbc_ram_enable;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		mbc_rom_bank_reg <= savestate_data[ 8: 0]; //9'd1;
		mbc_ram_bank_reg <= savestate_data[12: 9]; //4'd0;
		mbc_ram_enable   <= savestate_data[   15]; //1'b0;
	end else if(~enable) begin
		mbc_rom_bank_reg <= 9'd1;
		mbc_ram_bank_reg <= 4'd0;
		mbc_ram_enable   <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_a15) begin
			case(cart_addr[14:13])
				2'b00: mbc_ram_enable <= (cart_di == 8'h0A); //RAM enable/disable
				2'b01: if (cart_addr[12])
							mbc_rom_bank_reg[8] <= cart_di[0]; //ROM bank register 3000-3FFF High bit
					   else
							mbc_rom_bank_reg[7:0] <= cart_di; // ROM bank register 2000-2FFF Low 8 bits
				2'b10: mbc_ram_bank_reg <= cart_di[3:0]; //  RAM bank register
			 endcase
		end
	end
end

assign mbc_addr = { mbc5_rom_bank, cart_addr[13:0] };	// 16k ROM Bank 0-480 (0h-1E0h)
assign ram_enabled = mbc_ram_enable & has_ram;

assign cram_do = ram_enabled ? cram_di : 8'hFF;
assign cram_addr = { mbc5_ram_bank, cart_addr[12:0] };
assign has_battery = (cart_mbc_type == 8'h1B || cart_mbc_type == 8'h1E);

endmodule