module gb_camera (
	input         enable,
	input         reset,

	input         clk_sys,
	input         ce_cpu,

	input         savestate_load,
	input  [15:0] savestate_data,
	inout  [15:0] savestate_back_b,

	input   [3:0] ram_mask,
	input   [8:0] rom_mask,

	input  [14:0] cart_addr,
	input         cart_a15,

	input   [7:0] cart_mbc_type,

	input         cart_rd,
	input         cart_wr,
	input   [7:0] cart_di,
	inout         cart_oe_b,

	input         cram_rd,
	input   [7:0] cram_di,
	inout   [7:0] cram_do_b,
	inout  [16:0] cram_addr_b,

	inout  [22:0] mbc_addr_b,
	inout         ram_enabled_b,
	inout         has_battery_b
);

wire [22:0] mbc_addr;
wire [7:0] cram_do;
wire [16:0] cram_addr;
wire cart_oe;
wire ram_enabled;
wire has_battery;
wire [15:0] savestate_back;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign cart_oe_b        = enable ? cart_oe        :  1'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 16'hZ;

// --------------------- CPU register interface ------------------

reg [5:0] rom_bank_reg;
reg [3:0] ram_bank_reg;
reg ram_write_en;
reg cam_en;

assign savestate_back[ 5: 0] = rom_bank_reg;
assign savestate_back[ 8: 6] = 0;
assign savestate_back[12: 9] = ram_bank_reg;
assign savestate_back[   13] = 0;
assign savestate_back[   14] = cam_en;
assign savestate_back[   15] = ram_write_en;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg <= savestate_data[ 5: 0]; //6'd1;
		ram_bank_reg <= savestate_data[12: 9]; //4'd0;
		cam_en       <= savestate_data[   14]; //1'b0;
		ram_write_en   <= savestate_data[   15]; //1'b0;
	end else if(~enable) begin
		rom_bank_reg <= 6'd1;
		ram_bank_reg <= 4'd0;
		cam_en       <= 1'b0;
		ram_write_en   <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_a15) begin
			case(cart_addr[14:13])
				2'b00: ram_write_en <= (cart_di[3:0] == 4'ha); //RAM write enable/disable
				2'b01: rom_bank_reg <= cart_di[5:0]; //write to ROM bank register
				2'b10: begin
					if (cart_di[4]) begin
						cam_en <= 1'b1; //enable CAM registers
					end else begin
						cam_en <= 1'b0; //enable RAM
						ram_bank_reg <= cart_di[3:0]; //write to RAM bank register
					end
				end
			endcase
		end
	end
end

wire [3:0] ram_bank = ram_bank_reg & ram_mask[3:0];

// 0x0000-0x3FFF = Bank 0
wire [5:0] rom_bank = (~cart_addr[14]) ? 6'd0 : rom_bank_reg;

// mask address lines to enable proper mirroring
wire [5:0] rom_bank_m = rom_bank & rom_mask[5:0];  //64

assign mbc_addr = { 3'b000, rom_bank_m, cart_addr[13:0] };	// 16k ROM Bank 0-63

assign cram_do = cam_en ? 8'h00 : cram_di; // Reading from RAM or CAM is always enabled
assign cram_addr = { ram_bank, cart_addr[12:0] };

assign cart_oe = (cart_rd & ~cart_a15) | cram_rd;

assign has_battery = 1;
assign ram_enabled = ~cam_en & ram_write_en; // Writing RAM

endmodule