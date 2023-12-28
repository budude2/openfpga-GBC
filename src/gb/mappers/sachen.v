module sachen (
	input         enable,

	input         clk_sys,
	input         ce_cpu,

	input         isGBC_game,

	input         savestate_load,
	input [63:0]  savestate_data,
	inout [63:0]  savestate_back_b,

	input [14:0]  cart_addr,
	input         cart_a15,

	input         cart_wr,
	input  [7:0]  cart_di,

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
wire        has_battery;
wire [63:0] savestate_back;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 64'hZ;

// --------------------- CPU register interface ------------------

// https://wiki.tauwasser.eu/view/Sachen_Mappers

reg [7:0] rom_bank_reg;
reg [7:0] base_rom_bank;
reg [7:0] rom_bank_mask;
reg       header_end;
reg       prev_a15;
reg       prev_nCS;
reg [5:0] a15_cnt;
reg       a7_set;
reg       init;

// ROM bank bits 5-4 are used to enable write access to the Base ROM Bank Register 
// and ROM bank mask register
wire map_wr_en = &rom_bank_reg[5:4];

assign savestate_back[ 7: 0] = rom_bank_reg;
assign savestate_back[15: 8] = base_rom_bank;
assign savestate_back[23:16] = rom_bank_mask;
assign savestate_back[   24] = header_end;
assign savestate_back[   25] = prev_a15;
assign savestate_back[   26] = prev_nCS;
assign savestate_back[32:27] = a15_cnt;
assign savestate_back[   33] = a7_set;
assign savestate_back[   34] = init;
assign savestate_back[63:35] = 0;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg  <= savestate_data[ 7: 0]; //8'd1;
		base_rom_bank <= savestate_data[15: 8]; //8'd0;
		rom_bank_mask <= savestate_data[23:16]; //8'd0;
		header_end    <= savestate_data[   24]; //1'b0;
		prev_a15      <= savestate_data[   25]; //1'b1;
		prev_nCS      <= savestate_data[   26]; //1'b1;
		a15_cnt       <= savestate_data[32:27]; //6'd0;
		a7_set        <= savestate_data[   33]; //1'b0;
		init          <= savestate_data[   34]; //1'b0;
	end else if(~enable) begin
		rom_bank_reg   <= 8'd1;
		base_rom_bank  <= 8'd0;
		rom_bank_mask  <= 8'd0;
		header_end     <= 1'b0;
		prev_a15       <= 1'b1;
		prev_nCS       <= 1'b1;
		a15_cnt        <= 6'd0;
		a7_set         <= 1'b0;
		init           <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_a15) begin
			case(cart_addr[14:13])
				2'b00: if (map_wr_en) base_rom_bank <= cart_di[7:0]; // Base ROM bank register
				2'b01: rom_bank_reg <= (cart_di[7:0] == 0) ? 8'd1 : cart_di[7:0]; // ROM bank register
				2'b10: if (map_wr_en) rom_bank_mask <= cart_di[7:0]; // ROM bank mask register
				default: ;
			endcase
		end

		if (~init) begin
			init <= 1'b1;
			a7_set <= ~isGBC_game;
		end

		// The bios reads the 48 byte header logo twice.
		// A15 goes low when the bios reads the ROM header.
		// Sachen MMC1 (GB) A7 set -> A7 passthrough
		// Sachen MMC2 (CGB) A7 passthrough -> A7 set -> A7 passthrough
		prev_a15 <= cart_a15;
		if (~prev_a15 & cart_a15 & ~header_end) begin
			a15_cnt <= a15_cnt + 1'b1;
			if (a15_cnt == 6'd47) begin
				a7_set <= ~a7_set;
				if (~a7_set) a15_cnt <= 0;
				if (a7_set)  header_end <= 1'b1;
			end
		end

		// Sachen MMC2: Skip to A7 set when nCS rises
		prev_nCS <= nCS;
		if (isGBC_game & ~header_end & ~prev_nCS & nCS) begin
			a7_set <= 1'b1;
			a15_cnt <= 0;
		end

	end
end

// 0x0000-0x3FFF = Bank 0
wire [7:0] rom_bank_a = (~cart_addr[14]) ? 8'd0 : rom_bank_reg;

wire [7:0] rom_bank = (rom_bank_a & ~rom_bank_mask) | (base_rom_bank & rom_bank_mask);

wire header_read = ~cart_a15 && !cart_addr[14:9] && cart_addr[8];

// Sachen scrambled the address during header read.
wire [6:0] header_addr = { cart_addr[0], cart_addr[5], cart_addr[1], cart_addr[3:2], cart_addr[4], cart_addr[6] };

assign mbc_addr[   22] = 0;
assign mbc_addr[21:14] = rom_bank; // 16k ROM Bank 0-255
assign mbc_addr[13: 8] = cart_addr[13:8];
assign mbc_addr[    7] = (cart_addr[7] | a7_set);
assign mbc_addr[ 6: 0] = (header_read) ? header_addr : cart_addr[6:0];

assign cram_do = 8'hFF;
assign cram_addr = { 4'd0, cart_addr[12:0] };

assign ram_enabled = 0;
assign has_battery = 0;

endmodule