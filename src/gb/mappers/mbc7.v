module mbc7 (
	input         enable,
	input         reset,

	input         clk_sys,
	input         ce_cpu,
	input         ce_1x, // 4Mhz

	input         savestate_load,
	input  [15:0] savestate_data,
	inout  [15:0] savestate_back_b,
	input  [63:0] savestate_data2,
	inout  [63:0] savestate_back2_b,

	input  [7:0]  joystick_analog_x,
	input  [7:0]  joystick_analog_y,

	input         has_ram,
	input   [3:0] ram_mask,
	input   [8:0] rom_mask,

	input  [14:0] cart_addr,
	input         cart_a15,

	input   [7:0] cart_mbc_type,

	input         cart_rd,
	input         cart_wr,
	input   [7:0] cart_di,
	inout         cart_oe_b,

	input         nCS,

	input   [7:0] cram_di,
	inout   [7:0] cram_do_b,
	inout  [16:0] cram_addr_b,

	inout         cram_wr_b,
	inout   [7:0] cram_wr_do_b,

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
wire [63:0] savestate_back2;
wire [7:0] cram_wr_do;
wire cram_wr;
wire is_cram_addr = ~nCS & ~cart_addr[14];

assign mbc_addr_b        = enable ? mbc_addr        : 23'hZ;
assign cram_do_b         = enable ? cram_do         :  8'hZ;
assign cram_addr_b       = enable ? cram_addr       : 17'hZ;
assign cart_oe_b         = enable ? cart_oe         :  1'hZ;
assign ram_enabled_b     = enable ? ram_enabled     :  1'hZ;
assign has_battery_b     = enable ? has_battery     :  1'hZ;
assign savestate_back_b  = enable ? savestate_back  : 16'hZ;
assign savestate_back2_b = enable ? savestate_back2 : 64'hZ;
assign cram_wr_do_b      = enable ? cram_wr_do      :  8'hZ;
assign cram_wr_b         = enable ? cram_wr         :  1'hZ;

// --------------------- CPU register interface ------------------

reg [6:0] rom_bank_reg;
reg ram_enable1, ram_enable2;
reg [15:0] accelerometer_x, accelerometer_y;
reg accel_latched;

reg eeprom_di, eeprom_clk, eeprom_cs;

wire ram_reg_en = ram_enable1 & ram_enable2;
wire ram_reg_sel = is_cram_addr & ~cart_addr[12]; // $A000-AFFF

assign savestate_back[ 6: 0] = rom_bank_reg;
assign savestate_back[    7] = ram_enable1;
assign savestate_back[    8] = ram_enable2;
assign savestate_back[    9] = eeprom_di;
assign savestate_back[   10] = eeprom_clk;
assign savestate_back[   11] = eeprom_cs;
assign savestate_back[15:12] = 0;


always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg <= savestate_data[ 6: 0]; //7'd1;
		ram_enable1  <= savestate_data[    7]; //1'b0;
		ram_enable2  <= savestate_data[    8]; //1'b0;
		eeprom_di    <= savestate_data[    9]; //1'b0;
		eeprom_clk   <= savestate_data[   10]; //1'b0;
		eeprom_cs    <= savestate_data[   11]; //1'b0;
	end else if(~enable) begin
		rom_bank_reg <= 7'd1;
		ram_enable1  <= 1'b0;
		ram_enable2  <= 1'b0;
		accel_latched <= 1'b0;
		accelerometer_x <= 16'h8000;
		accelerometer_y <= 16'h8000;
		eeprom_di <= 1'b0;
		eeprom_clk <= 1'b0;
		eeprom_cs <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr) begin
			if (~cart_a15) begin
				case(cart_addr[14:13])
					2'b00: ram_enable1 <= (cart_di[3:0] == 4'ha); //RAM enable/disable
					2'b01: rom_bank_reg <= cart_di[6:0]; // ROM bank register
					2'b10: ram_enable2 <= (cart_di == 8'h40); //RAM enable/disable
				 endcase
			end
			if (ram_reg_en & ram_reg_sel) begin
				case(cart_addr[7:4])
					0: if (cart_di == 8'h55) begin
							accel_latched <= 1'b0;
							accelerometer_x <= 16'h8000;
							accelerometer_y <= 16'h8000;
						end
					1: if (cart_di == 8'hAA && ~accel_latched) begin
							accel_latched <= 1'b1;
							accelerometer_x <= 16'h81D0 - $signed(joystick_analog_x);
							accelerometer_y <= 16'h81D0 - $signed(joystick_analog_y);
						end
					8: { eeprom_cs, eeprom_clk, eeprom_di } <= { cart_di[7:6], cart_di[1] };
				 endcase
			end
		end
	end
end

wire [7:0] cram_addr_e;
wire eeprom_do;
eeprom93LC56 eeprom(
	.enable        ( enable ),

	.clk_sys       ( clk_sys ),
	.ce            ( ce_1x ),

	.data_clk      ( eeprom_clk ),
	.data_in       ( eeprom_di ),

	.cs            ( eeprom_cs ),

	.ram_di        ( cram_di  ),
	.ram_addr      ( cram_addr_e ),
	.ram_wr        ( cram_wr ),
	.ram_do        ( cram_wr_do ),

	.data_out      ( eeprom_do ),

	.savestate_load ( savestate_load  ),
	.savestate_data ( savestate_data2 ),
	.savestate_back ( savestate_back2 )
);

reg [7:0] cram_do_r;
always @* begin
	cram_do_r = 8'hFF;
	if (ram_reg_en & ram_reg_sel) begin
		case(cart_addr[7:4])
			2: cram_do_r = accelerometer_x[ 7:0];
			3: cram_do_r = accelerometer_x[15:8];
			4: cram_do_r = accelerometer_y[ 7:0];
			5: cram_do_r = accelerometer_y[15:8];
			6: cram_do_r = 8'h00; // Unknown
			7: cram_do_r = 8'hFF; // Unknown
			8: { cram_do_r[7:6], cram_do_r[1:0] } = { eeprom_cs, eeprom_clk, eeprom_di, eeprom_do };
			default: ;
		endcase
	end
end

// 0x0000-0x3FFF = Bank 0
wire [6:0] rom_bank = (~cart_addr[14]) ? 7'd0 : rom_bank_reg;

// mask address lines to enable proper mirroring
wire [6:0] rom_bank_m = rom_bank & rom_mask[6:0];  //512

assign mbc_addr = { 2'b00, rom_bank_m, cart_addr[13:0] };	// 16k ROM Bank 0-511

assign cram_do = cram_do_r;
assign cram_addr = { 9'd0, cram_addr_e };

assign cart_oe = cart_rd & (~cart_a15 | (ram_reg_en & ram_reg_sel));

assign has_battery = 1;
assign ram_enabled = 0; // EEPROM

endmodule

// EEPROM
module eeprom93LC56 (
	input enable,

	input clk_sys,
	input ce,

	input data_clk,
	input data_in,

	input cs,

	input  [7:0] ram_di,
	output [7:0] ram_addr,
	output [7:0] ram_do,
	output ram_wr,

	output data_out,

	input         savestate_load,
	input  [63:0] savestate_data,
	output [63:0] savestate_back
 );

reg        old_data_clk, old_cs;
reg  [9:0] command;
reg        command_start, command_run, command_init;
reg  [4:0] data_clk_cnt;
reg [16:0] data; // [15:8] = Low byte, [7:0] = High byte
reg        write_en, writing;
reg  [7:0] rw_cnt;
reg  [7:0] ram_addr_r, ram_do_r;
reg        ram_wr_r;

wire command_write = (command[9:8] == 2'b01);
wire command_read  = (command[9:8] == 2'b10);
wire command_erase = (command[9:8] == 2'b11);

wire command_ewds  = (command[9:6] == 4'b0000); // Write disable
wire command_wral  = (command[9:6] == 4'b0001); // Fill with value
wire command_eral  = (command[9:6] == 4'b0010); // Fill 0xFF
wire command_ewen  = (command[9:6] == 4'b0011); // Write enable

assign savestate_back[    0] = old_data_clk;
assign savestate_back[    1] = old_cs;
assign savestate_back[11: 2] = command;
assign savestate_back[   12] = command_start;
assign savestate_back[   13] = command_run;
assign savestate_back[   14] = command_init;
assign savestate_back[19:15] = data_clk_cnt;
assign savestate_back[36:20] = data;
assign savestate_back[   37] = write_en;
assign savestate_back[   38] = writing;
assign savestate_back[46:39] = rw_cnt;
assign savestate_back[54:47] = ram_addr_r;
assign savestate_back[62:55] = ram_do_r;
assign savestate_back[   63] = ram_wr_r;

always @(posedge clk_sys) begin
	if (savestate_load & enable) begin
		old_data_clk  <= savestate_data[    0];
		old_cs        <= savestate_data[    1];
		command       <= savestate_data[11: 2];
		command_start <= savestate_data[   12];
		command_run   <= savestate_data[   13];
		command_init  <= savestate_data[   14];
		data_clk_cnt  <= savestate_data[19:15];
		data          <= savestate_data[36:20];
		write_en      <= savestate_data[   37];
		writing       <= savestate_data[   38];
		rw_cnt        <= savestate_data[46:39];
		ram_addr_r    <= savestate_data[54:47];
		ram_do_r      <= savestate_data[62:55];
		ram_wr_r      <= savestate_data[   63];
	end else if (~enable) begin
		old_data_clk <= 0;
		old_cs <= 0;
		command <= 0;
		command_start <= 0;
		command_run <= 0;
		command_init <= 0;
		data_clk_cnt <= 0;
		write_en <= 0;
		writing <= 0;
		ram_wr_r <= 0;
	end else if(ce) begin
		old_data_clk <= data_clk;
		old_cs <= cs;

		if (~cs) begin // Reset
			command_start <= 0;
			command_run <= 0;
			command_init <= 0;
		end else begin

			if (~old_data_clk & data_clk) begin
				data_clk_cnt <= data_clk_cnt + 1'b1;

				if (~command_start & data_in & ~writing) begin
					command_start <= 1;
					data_clk_cnt <= 0;
				end

				if (command_start & ~command_run) begin
					command <= { command[8:0], data_in };
					if (data_clk_cnt == 9) begin
						data_clk_cnt <= 0;
						command_run <= 1;
						command_init <= 1;
					end
				end

				if(command_run) begin
					if (command_read) begin
						data <= { data[15:0], 1'b0 };
						if (data_clk_cnt == 15) begin // Sequential read. Fetch next data
							data_clk_cnt <= 0;
							rw_cnt <= 0;
							command[6:0] <= command[6:0] + 1'b1;
						end
					end

					if (command_write | command_wral) begin
						data <= { data[15:0], data_in };
					end
				end
			end

			if (command_init) begin
				command_init <= 0;

				if (command_ewds)
					write_en <= 0;

				if (command_ewen)
					write_en <= 1;

				if (command_read) begin
					rw_cnt <= 0;
					data[16] <= 1'b0; // Dummy zero bit
				end
			end

			if (command_run) begin
				if(command_read && rw_cnt <= 2) begin // Fetch data
					ram_addr_r <= { command[6:0], rw_cnt[0] };

					case (rw_cnt)
						1: data[15:8] <= ram_di;
						2: data[7:0]  <= ram_di;
						default: ;
					endcase

					rw_cnt <= rw_cnt + 1'b1;
				end
			end

		end

		if (old_cs & ~cs & write_en) begin
			if ( (command_erase | command_eral)
				|| ((command_write | command_wral) && data_clk_cnt == 16) ) begin
				writing <= 1;
				rw_cnt <= 0;
			end
		end

		ram_wr_r <= 0;
		if (writing) begin
			ram_wr_r <= 1;
			ram_addr_r <= (command_wral | command_eral) ? rw_cnt : { command[6:0], rw_cnt[0] };
			ram_do_r <= (command_erase | command_eral) ? 8'hFF : (rw_cnt[0] ? data[7:0] : data[15:8]);
			rw_cnt <= rw_cnt + 1'b1;

			if (rw_cnt == ((command_wral | command_eral) ? 255 : 1) ) begin
				writing <= 0;
			end
		end


	end
end

assign ram_addr = ram_addr_r;
assign ram_do   = ram_do_r;
assign ram_wr   = ram_wr_r;

assign data_out = command_run & command_read ? data[16] : ~writing;

endmodule