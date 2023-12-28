module rocket (
	input         enable,

	input         clk_sys,
	input         ce_cpu,

	input         savestate_load,
	input [15:0]  savestate_data,
	inout [15:0]  savestate_back_b,

	input         has_ram,
	input  [1:0]  ram_mask,
	input  [4:0]  rom_mask,

	input [14:0]  cart_addr,
	input         cart_a15,

	input  [7:0]  cart_mbc_type,

	input         cart_wr,
	input  [7:0]  cart_di,

	input  [7:0]  rom_di,
	inout  [7:0]  rom_do_b,

	input  [7:0]  cram_di,
	inout  [7:0]  cram_do_b,
	inout [16:0]  cram_addr_b,

	inout [22:0]  mbc_addr_b,
	inout         ram_enabled_b,
	inout         has_battery_b
);

wire [22:0] mbc_addr;
wire  [7:0] rom_do;
wire        ram_enabled;
wire  [7:0] cram_do;
wire [16:0] cram_addr;
wire        has_battery;
wire [15:0] savestate_back;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign rom_do_b         = enable ? rom_do         :  8'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 16'hZ;

// --------------------- CPU register interface ------------------
reg [3:0] rom_bank_reg;
reg       rom_outer_bank;
reg       header_end;
reg       prev_a15;
reg [5:0] a15_cnt;

assign savestate_back[ 3: 0] = rom_bank_reg;
assign savestate_back[    4] = rom_outer_bank;
assign savestate_back[    5] = header_end;
assign savestate_back[    6] = prev_a15;
assign savestate_back[12: 7] = a15_cnt;
assign savestate_back[15:13] = 0;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg   <= savestate_data[ 3: 0]; //4'd1;
		rom_outer_bank <= savestate_data[    4]; //1'b0;
		header_end     <= savestate_data[    5]; //1'b0;
		prev_a15       <= savestate_data[    6]; //1'b1;
		a15_cnt        <= savestate_data[12: 7]; //6'd0;
	end else if(~enable) begin
		rom_bank_reg   <= 4'd1;
		rom_outer_bank <= 1'b0;
		header_end     <= 1'b0;
		prev_a15       <= 1'b1;
		a15_cnt        <= 6'd0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_a15) begin
			if (cart_addr[14:13] == 2'b01) begin // $2000-3FFF
				if (&cart_addr[7:6]) begin
					rom_outer_bank <= cart_di[0]; // Multi-games seem to write to $3FC0
				end else begin
					rom_bank_reg <= (cart_di[3:0] == 0) ? 4'd1 : cart_di[3:0]; //write to ROM bank register
				end
			end
		end

		// The bios reads the 48 byte header logo twice.
		// A15 goes low when the bios reads the ROM header.
		prev_a15 <= cart_a15;
		if (~prev_a15 & cart_a15 & ~header_end) begin
			a15_cnt <= a15_cnt + 1'b1;
			if (a15_cnt == 6'd47) begin
				header_end <= 1'b1;
			end
		end
	end
end

wire [7:0] header_xor[52] = '{
	'h00, 'h00, 'h00, 'h00,
	'hDF, 'hCE, 'h97, 'h78, 'hCD, 'h2F, 'hF0, 'h0B, 'h0B, 'hEA, 'h78, 'h83, 'h08, 'h1D, 'h9A, 'h45,
	'h11, 'h2B, 'hE1, 'h11, 'hF8, 'h88, 'hF8, 'h8E, 'hFE, 'h88, 'h2A, 'hC4, 'hFF, 'hFC, 'hD9, 'h87,
	'h22, 'hAB, 'h67, 'h7D, 'h77, 'h2C, 'hA8, 'hEE, 'hFF, 'h9B, 'h99, 'h91, 'hAA, 'h9B, 'h33, 'h3E
};

// 0x0000-0x3FFF = Bank 0
wire [3:0] rom_bank_a = (~cart_addr[14]) ? 4'd0 : rom_bank_reg;

// Max 256KB + Outer bank for Multi-games (2x 256KB)
wire [4:0] rom_bank = { rom_outer_bank, rom_bank_a };

// mask address lines to enable proper mirroring
wire [4:0] rom_bank_m = rom_bank & rom_mask[4:0];

assign mbc_addr = { 4'b0000, rom_bank_m, cart_addr[13:0] };

assign rom_do = (~header_end) ? (rom_di ^ header_xor[cart_addr[5:0]]) : rom_di;

assign cram_do = 8'hFF;
assign cram_addr = { 4'b0000, cart_addr[12:0] };

assign ram_enabled = 0;
assign has_battery = 0;

endmodule