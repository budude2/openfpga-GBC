module megaduck (
	input         enable,

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


// Megaduck banks are pretty simple. They are broken up into chunks of 0x4000. So bank 0
// is 0-0x3fff, bank 1 is 0x4000-0x7fff and so on. On most carts, only the top 0x4000 of the rom
// can be bank switched and the bottom is fixed at bank 0. In this case, the bank number is
// written to address 0x0001. Note that the bank can never be less than 1 for the upper bank.
// On some roms, a ram address is written instead which changes the entire visible rom space
// instead of just the upper slot.

reg [7:0] bank_top, bank_bottom;

// --------------------- CPU register interface ------------------

assign savestate_back[ 7: 0] = bank_bottom;
assign savestate_back[15: 8] = bank_top; // The top bank can never be less than 1

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		bank_bottom <= savestate_data[7:0];
		bank_top <= savestate_data[15:8];
	end else if(~enable) begin
		bank_bottom <= 8'd0;
		bank_top <= 8'd1;
	end else if(ce_cpu) begin
		if (cart_wr) begin
			if (~cart_a15 && cart_addr == 1) begin
				bank_top <= (cart_di[7:0] == 0) ? 8'd1 : cart_di;
			end
			else if (cart_a15 && ~cart_addr[14]) begin
				bank_top <= {cart_di[6:0], 1'b1};
				bank_bottom <= {cart_di[6:0], 1'b0};
			end
		end
	end
end

assign mbc_addr = { 1'b0, (cart_addr[14] ? bank_top : bank_bottom), cart_addr[13:0] };
assign ram_enabled = 0;

assign cram_do = ram_enabled ? cram_di : 8'hFF;
assign cram_addr = 17'd0;
assign has_battery = 0;


endmodule