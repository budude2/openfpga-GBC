module misc_mapper (
	input         enable,

	input         clk_sys,
	input         ce_cpu,
	
	input         mapper_sel, // 0: Wisdom Tree, 1: Mani DMG-601

	input         savestate_load,
	input [15:0]  savestate_data,
	inout [15:0]  savestate_back_b,

	input  [8:0]  rom_mask,

	input [14:0]  cart_addr,
	input         cart_a15,

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
wire        ram_enabled;
wire  [7:0] cram_do;
wire [16:0] cram_addr;
wire        has_battery;
wire [15:0] savestate_back;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 16'hZ;

// --------------------- CPU register interface ------------------
reg [7:0] rom_bank_reg;
reg       map_disable;

assign savestate_back[ 7: 0] = rom_bank_reg;
assign savestate_back[    8] = map_disable;
assign savestate_back[15: 9] = 0;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg  <= savestate_data[ 7: 0]; //8'd0;
		map_disable   <= savestate_data[    8]; //1'b0;
	end else if(~enable) begin
		rom_bank_reg  <= 8'd0;
		map_disable   <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_a15) begin
			if (mapper_sel) begin
				// Mani DMG-601
				if (~map_disable) begin
					rom_bank_reg <= { 5'd0, cart_di[2:0] };
					map_disable <= 1'b1;
				end
			end else begin
				// Wisdom Tree
				rom_bank_reg <= cart_addr[7:0];
			end
		end
	end
end

// mask address lines to enable proper mirroring
wire [7:0] rom_bank = rom_bank_reg & rom_mask[8:1];

assign mbc_addr = { rom_bank, cart_addr[14:0] };

assign cram_do = 8'hFF;
assign cram_addr = { 4'b0000, cart_addr[12:0] };

assign ram_enabled = 0;
assign has_battery = 0;

endmodule