module mbc6 (
	input        enable,

	input        clk_sys,
	input        ce_cpu,

	input        savestate_load,
	input [63:0] savestate_data,
	inout [63:0] savestate_back_b,

	input        has_ram,
	input  [1:0] ram_mask,
	input  [5:0] rom_mask,

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
wire [63:0] savestate_back;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 64'hZ;

// --------------------- CPU register interface ------------------

reg [6:0] rom_bank_reg_a;
reg [6:0] rom_bank_reg_b;
reg [2:0] ram_bank_reg_a;
reg [2:0] ram_bank_reg_b;
reg ram_enable;

assign savestate_back[ 6: 0] = rom_bank_reg_a;
assign savestate_back[13: 7] = rom_bank_reg_b;
assign savestate_back[16:14] = ram_bank_reg_a;
assign savestate_back[19:17] = ram_bank_reg_b;
assign savestate_back[   20] = ram_enable;
assign savestate_back[63:21] = 0;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg_a <= savestate_data[ 6: 0]; // 7'd0;
		rom_bank_reg_b <= savestate_data[13: 7]; // 7'd0;
		ram_bank_reg_a <= savestate_data[16:14]; // 3'd0;
		ram_bank_reg_b <= savestate_data[19:17]; // 3'd0;
		ram_enable     <= savestate_data[   20]; // 1'b0;
	end else if(~enable) begin
		rom_bank_reg_a <= 7'd0;
		rom_bank_reg_b <= 7'd0;
		ram_bank_reg_a <= 3'd0;
		ram_bank_reg_b <= 3'd0;
		ram_enable     <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr) begin
			if (~cart_a15 && !cart_addr[14:13]) begin // $0000-1FFF
				case(cart_addr[12:10])
					3'd0: ram_enable <= (cart_di[3:0] == 4'hA); //RAM enable/disable
					3'd1: ram_bank_reg_a <= cart_di[2:0]; // 4KB RAM bank A ($A000-AFFF)
					3'd2: ram_bank_reg_b <= cart_di[2:0]; // 4KB RAM bank B ($B000-BFFF)
					3'd3: ; // Flash enable
					3'd4: ; // Flash write enable
					default: ;
				endcase
			end
			if (~cart_a15 && cart_addr[14:13] == 2'b01) begin // $2000-3FFF
				case(cart_addr[12:11])
					2'd0: rom_bank_reg_a  <= cart_di[6:0]; // 8KB ROM bank A ($4000-5FFF)
					2'd1: ; //rom_flash_sel_a <= (cart_di[3:0] == 4'h8); // ROM/Flash A select
					2'd2: rom_bank_reg_b  <= cart_di[6:0]; // 8KB ROM bank B ($6000-7FFF)
					2'd3: ; //rom_flash_sel_b <= (cart_di[3:0] == 4'h8); // ROM/Flash B select
				endcase
			end
		end
	end
end

reg [6:0] rom_bank;
always @* begin
	if (~cart_addr[14]) begin // $0000-3FFF
		rom_bank = { 6'd0, cart_addr[13] };
	end else if (~cart_addr[13]) begin // $4000-5FFF
		rom_bank = rom_bank_reg_a;
	end else begin // $6000-7FFF
		rom_bank = rom_bank_reg_b;
	end
end

reg [2:0] ram_bank;
always @* begin
	if (~cart_addr[12]) begin // $A000-AFFF
		ram_bank = ram_bank_reg_a;
	end else begin // $B000-BFFF
		ram_bank = ram_bank_reg_b;
	end
end

// mask address lines to enable proper mirroring
wire [6:0] rom_bank_m = rom_bank & { rom_mask[5:0], 1'b1 }; // 64x16KB Mask
wire [2:0] ram_bank_m = ram_bank & { ram_mask[1:0], 1'b1 }; // 4x8KB Mask

assign mbc_addr = { 3'd0, rom_bank_m, cart_addr[12:0] };	// 8KB ROM Bank 0-127

assign cram_do = ram_enabled ? cram_di : 8'hFF;
assign cram_addr = { 2'd0, ram_bank_m, cart_addr[11:0] }; // 4KB RAM Bank 0-7

assign has_battery = has_ram;
assign ram_enabled = ram_enable & has_ram;

endmodule