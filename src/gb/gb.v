//
// gb.v
//
// Gameboy for the MIST board https://github.com/mist-devel
// 
// Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module gb (
   input reset,
   
	input clk_sys,
	input ce,
	input ce_2x,

	input [7:0] joystick,
	input isGBC,
    input real_cgb_boot,
	input isSGB,

	// cartridge interface
	// can adress up to 1MB ROM
	output [14:0] ext_bus_addr,
	output ext_bus_a15,
	output cart_rd,
	output cart_wr,
	input [7:0] cart_do,
	output [7:0] cart_di,
	input  cart_oe,

	// WRAM or Cart RAM CS
	output nCS,

	input cgb_boot_download,
	input dmg_boot_download,
	input sgb_boot_download,
	input         ioctl_wr,
	input  [24:0] ioctl_addr,
	input  [15:0] ioctl_dout,

    // Bootrom features
	input boot_gba_en,
    input fast_boot_en,

	// audio
	output [15:0] audio_l,
	output [15:0] audio_r,

	// Megaduck?
	input megaduck,

	// lcd interface
	output lcd_clkena,
	output [14:0] lcd_data,
	output [1:0] lcd_data_gb,
	output [1:0] lcd_mode,
	output lcd_on,
	output lcd_vsync,

	output [1:0] joy_p54,
	input  [3:0] joy_din,
	
	output speed,   //GBC
	output DMA_on,
	
	input          gg_reset,
	input          gg_en,
	input  [128:0] gg_code,
	output         gg_available,

	//serial port
	output sc_int_clock2,
	input serial_clk_in,
	output serial_clk_out,
	input  serial_data_in,
	output serial_data_out,
	
	// savestates
	input        increaseSSHeaderCount,
	input  [7:0] cart_ram_size,
	input        save_state,
	input        load_state,
	input  [1:0] savestate_number,
	output       sleep_savestate,
	
	output [63:0] SaveStateExt_Din, 
	output [9:0]  SaveStateExt_Adr, 
	output        SaveStateExt_wren,
	output        SaveStateExt_rst, 
	input  [63:0] SaveStateExt_Dout,
	output        SaveStateExt_load,
	
	output [19:0] Savestate_CRAMAddr,     
	output        Savestate_CRAMRWrEn,    
	output [7:0]  Savestate_CRAMWriteData,
	input  [7:0]  Savestate_CRAMReadData,

	output [63:0] SAVE_out_Din,  	// data read from savestate
	input  [63:0] SAVE_out_Dout, 	// data written to savestate
	output [25:0] SAVE_out_Adr,  	// all addresses are DWORD addresses!
	output        SAVE_out_rnw,     // read = 1, write = 0
	output        SAVE_out_ena,     // one cycle high for each action
	output  [7:0] SAVE_out_be,     
	input         SAVE_out_done,    // should be one cycle high when write is done or read value is valid
	
	input         rewind_on,
	input         rewind_active
);

// savestates
wire [63:0] SaveStateBus_Din;
wire [9:0] SaveStateBus_Adr;
wire SaveStateBus_wren, SaveStateBus_rst;
  
wire [7:0] Savestate_RAMWriteData;
wire [7:0] Savestate_RAMReadData_WRAM, Savestate_RAMReadData_VRAM, Savestate_RAMReadData_ORAM, Savestate_RAMReadData_ZRAM;
wire [19:0] Savestate_RAMAddr;
wire [4:0] Savestate_RAMRWrEn;

localparam SAVESTATE_MODULES    = 8;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];

wire [56:0] SS_Top;
wire [56:0] SS_Top_BACK;
eReg_SavestateV #(0, 31, 56, 0, 64'h0000000000800001) iREG_SAVESTATE_Top (clk_sys, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[6], SS_Top_BACK, SS_Top);  

wire [10:0] SS_Top2;
wire [10:0] SS_Top2_BACK;
eReg_SavestateV #(0, 38, 10, 0, 64'h0000000000000000) iREG_SAVESTATE_Top2 (clk_sys, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[7], SS_Top2_BACK, SS_Top2);

// include cpu
reg boot_rom_enabled;

reg [1:0] ff4c_key0; // GBC DMG mode register
wire isGBC_mode = !ff4c_key0 | boot_rom_enabled;

wire [15:0] cpu_addr;
wire [7:0] cpu_do;

wire sel_timer = (cpu_addr[15:4] == 12'hff0) && (cpu_addr[3:2] == 2'b01);
wire sel_video_reg = (cpu_addr[15:4] == 12'hff4) || (isGBC && (cpu_addr[15:4] == 12'hff6) && (cpu_addr[3:0] >= 4'h8 && cpu_addr[3:0] <= 4'hC)); //video and oam dma (+ ff68-ff6C when gbc)
wire sel_video_oam = cpu_addr[15:8] == 8'hfe;
wire sel_joy  = cpu_addr == 16'hff00;                // joystick controller
wire sel_sb  = cpu_addr == 16'hff01;  			        // serial SB - Serial transfer data
wire sel_sc  = cpu_addr == 16'hff02;  			        // SC - Serial Transfer Control (R/W)
wire sel_rom  = !cpu_addr[15];                       // lower 32k are rom
wire sel_cram = cpu_addr[15:13] == 3'b101;           // 8k cart ram at $a000
wire sel_vram = cpu_addr[15:13] == 3'b100;           // 8k video ram at $8000
wire sel_ie   = cpu_addr == 16'hffff;                // interupt enable
wire sel_if   = cpu_addr == 16'hff0f;                // interupt flag
wire sel_wram = (cpu_addr[15:14] == 2'b11) && (~&cpu_addr[13:9]); // 8k internal ram at $C000-DFFF. C000-DDFF mirrored to E000-FDFF
wire sel_zpram = (cpu_addr[15:7] == 9'b111111111) && // 127 bytes zero pageram at $ff80
					 (cpu_addr != 16'hffff);
wire sel_audio = (cpu_addr[15:8] == 8'hff) &&        // audio reg ff10 - ff3f and ff76/ff77 PCM12/PCM34 (undocumented registers)
					((cpu_addr[7:5] == 3'b001) || (cpu_addr[7:4] == 4'b0001) || (cpu_addr[7:0] == 8'h76) || (cpu_addr[7:0] == 8'h77));

wire sel_ext_bus = sel_rom | sel_cram | sel_wram;

wire sel_boot_rom, sel_boot_rom_cgb;

// unused cgb registers
wire sel_FF72  = isGBC && cpu_addr == 16'hff72;            // unused register, all bits read/write
wire sel_FF73  = isGBC && cpu_addr == 16'hff73;            // unused register, all bits read/write
wire sel_FF74  = isGBC && isGBC_mode && (cpu_addr == 16'hff74); // unused register, all bits read/write, only in CGB mode
wire sel_FF75  = isGBC && cpu_addr == 16'hff75;            // unused register, bits 4-6 read/write

// Special MiSTer register for signalling to cpu bootrom
wire sel_FF50  = boot_rom_enabled && cpu_addr == 16'hff50;

wire ext_bus_wram_sel, ext_bus_cram_sel, ext_bus_rom_sel;
wire ext_bus_rd, ext_bus_wr;
wire [7:0] ext_bus_di;
wire cart_sel;


//  From Game Boy: Complete Technical Reference:
//  DMA register value, Selected bus, Asserted CS:
//  0x00-0x7F, external bus,  external ROM (A15)
//  0x80-0x9F, video RAM bus, video RAM (MCS)
//  0xA0-0xFF, external bus,  external RAM (CS)
wire [15:0] dma_addr;				
wire dma_sel_rom = ~dma_addr[15];                       // lower 32k are rom
wire dma_sel_vram = dma_addr[15:13] == 3'b100;          // 8k video ram at $8000-$9FFF
wire dma_sel_ext_bus_dmg = ~dma_sel_vram;               // WRAM or Cart ROM/RAM
wire dma_sel_ext_ram = ~dma_sel_rom;                    // External RAM CS

//CGB
wire dma_sel_cram = dma_addr[15:13] == 3'b101;          // 8k cart ram at $a000
wire dma_sel_wram = dma_addr[15:13] == 3'b110;          // 8k WRAM at $c000-$dfff
wire dma_sel_ext_bus_cgb = dma_sel_rom | dma_sel_cram;  // Cart ROM/RAM

wire dma_sel_ext_bus = isGBC ? dma_sel_ext_bus_cgb : dma_sel_ext_bus_dmg;

//CGB
wire sel_vram_bank = (cpu_addr==16'hff4f);
wire sel_wram_bank = isGBC && isGBC_mode && (cpu_addr==16'hff70);
wire sel_hdma = isGBC && isGBC_mode && (cpu_addr[15:4]==12'hff5) && 
					((cpu_addr[3:0]!=4'd0)&&(cpu_addr[3:0]< 4'd6)); //HDMA FF51-FF55 
wire sel_key0 = isGBC && boot_rom_enabled && (cpu_addr == 16'hff4c); // KEY0 - CGB / DMG mode register
wire sel_key1 = isGBC && isGBC_mode && (cpu_addr == 16'hff4d); // KEY1 - CGB Mode Only - Prepare Speed Switch
wire sel_rp = isGBC && isGBC_mode && (cpu_addr == 16'hff56); //FF56 - RP - CGB Mode Only - Infrared Communications Port

//HDMA can select from $0000 to $7ff0 or A000-DFF0
wire [15:0] hdma_source_addr;
wire hdma_sel_rom = !hdma_source_addr[15];                  // lower 32k are rom
wire hdma_sel_cram = hdma_source_addr[15:13] == 3'b101;     // 8k cart ram at $a000
wire hdma_sel_wram = hdma_source_addr[15:13] == 3'b110;     // 8k WRAM at $c000-$dff0
wire hdma_sel_ext_bus = hdma_sel_rom | hdma_sel_cram;

wire sc_start;
wire sc_shiftclock;
wire [7:0] sc_r = {sc_start,6'h3F,sc_shiftclock};

wire irq_ack;
wire [7:0] irq_vec;
reg [4:0] if_r;
reg [7:0] ie_r; // writing  $ffff sets the irq enable mask
wire irq_n;
				
reg [2:0] wram_bank; //1-7 FF70 - SVBK
reg vram_bank; //0-1 FF4F - VBK

wire [7:0] hdma_do;
wire hdma_active;

reg cpu_speed; // - 0 Normal mode (4MHz) - 1 Double Speed Mode (8MHz)
reg prepare_switch; // set to 1 to toggle speed

wire oam_cpu_allow;
wire vram_cpu_allow;

wire [7:0] joy_do;
wire [7:0] sb_o;
wire [7:0] timer_do;
wire [7:0] video_do;
wire [7:0] audio_do;
wire [7:0] boot_do;
wire [7:0] vram_do;
wire [7:0] vram1_do;
wire [7:0] zpram_do;
wire [7:0] wram_do;

reg[7:0] FF72;
reg[7:0] FF73;
reg[7:0] FF74;
reg[2:0] FF75;

// http://gameboy.mongenel.com/dmg/asmmemmap.html
wire [7:0] cpu_di = 
		irq_ack?irq_vec:
		sel_if?{3'b111, if_r}:  // interrupt flag register
		sel_rp?8'h02:
		sel_wram_bank?{5'h1f,wram_bank}:
		isGBC&&sel_vram_bank?{7'h7f,vram_bank}:
		sel_hdma?{hdma_do}:  //hdma GBC
		sel_key0 ? { 4'hF, ff4c_key0, 2'b10 } :
		sel_key1?{cpu_speed,6'h3f,prepare_switch}: //key1 cpu speed register(GBC)
		sel_joy?joy_do:         // joystick register
		sel_sb?sb_o:				// serial transfer data register
		sel_sc?sc_r:				// serial transfer control register
		sel_timer?timer_do:     // timer registers
		sel_video_reg?video_do: // video registers
		(sel_video_oam&&oam_cpu_allow)?video_do: // video object attribute memory
		sel_audio?audio_do:                                // audio registers
		sel_boot_rom?boot_do:                             // boot rom
		isGBC&sel_wram ? wram_do:                         // wram on GBC
		sel_ext_bus?ext_bus_di:                           // wram (DMG) + cartridge rom/ram
		(sel_vram&&vram_cpu_allow)?(isGBC&&vram_bank)?vram1_do:vram_do:       // vram (GBC bank 0+1)
		sel_zpram?zpram_do:     // zero page ram
		sel_ie?ie_r:  // interrupt enable register
		sel_FF72?FF72: // unused register, all bits read/write
		sel_FF73?FF73: // unused register, all bits read/write
		sel_FF74?FF74: // unused register, all bits read/write, only in CGB mode
		sel_FF75?{1'b1,FF75, 4'b1111}: // unused register, bits 4-6 read/write
        sel_FF50?{6'b0, fast_boot_en, boot_gba_en}: // MiSTer special instruction register 
		8'hff;

wire cpu_wr_n;
wire cpu_rd_n;
wire cpu_iorq_n;
wire cpu_m1_n;
wire cpu_mreq_n;

wire clk = clk_sys & ce;

wire ce_cpu = cpu_speed ? ce_2x:ce;
wire clk_cpu = clk_sys & ce_cpu;

// when hdma is enabled stop CPU (GBC). Finish read/write before stopping CPU
wire hdma_cpu_stop = (isGBC & hdma_active & cpu_rd_n & cpu_wr_n);
wire cpu_clken = ~hdma_cpu_stop & ce_cpu;

reg reset_r  = 1;
wire reset_ss;

//sync reset with clock
always  @ (posedge clk) begin
	reset_r <= reset;
end

reg old_cpu_wr_n;

assign SS_Top_BACK[54] = old_cpu_wr_n;

always @(posedge clk_sys) begin
	if(reset_ss) old_cpu_wr_n <= SS_Top[54]; // 1'b0
	else if (ce_cpu) old_cpu_wr_n <= cpu_wr_n;
end
wire cpu_wr_n_edge = ~(old_cpu_wr_n & ~cpu_wr_n);

wire cpu_stop;

wire genie_ovr;
wire [7:0] genie_data;
wire [15:0] cpu_addr_raw;

wire [7:0] snd_d_in;
wire [7:0] snd_d_out;
megaduck_swizzle md_swizz
(
	.megaduck   (megaduck),
	.a_in       (cpu_addr_raw),
	.a_out      (cpu_addr),

	.snd_in_di  (cpu_do),
	.snd_in_do  (snd_d_in),

	.snd_out_di (snd_d_out),
	.snd_out_do (audio_do)
);

GBse cpu (
	.RESET_n           ( !reset_ss        ),
	.CLK_n             ( clk_sys         ),
	.CLKEN             ( cpu_clken       ),
	.WAIT_n            ( 1'b1            ),
	.INT_n             ( irq_n           ),
	.NMI_n             ( 1'b1            ),
	.BUSRQ_n           ( 1'b1            ),
   .M1_n              ( cpu_m1_n        ),
   .MREQ_n            ( cpu_mreq_n      ),
   .IORQ_n            ( cpu_iorq_n      ),
   .RD_n              ( cpu_rd_n        ),
   .WR_n              ( cpu_wr_n        ),
   .RFSH_n            (                 ),
   .HALT_n            (                 ),
   .BUSAK_n           (                 ),
   .A                 ( cpu_addr_raw        ),
   .DI                ( genie_ovr ? genie_data : cpu_di),
   .DO                ( cpu_do          ),
	.STOP              ( cpu_stop        ),
    .isGBC             ( isGBC           ),
   // savestates
   .SaveStateBus_Din  (SaveStateBus_Din ), 
   .SaveStateBus_Adr  (SaveStateBus_Adr ),
   .SaveStateBus_wren (SaveStateBus_wren),
   .SaveStateBus_rst  (SaveStateBus_rst ),
   .SaveStateBus_Dout (SaveStateBus_wired_or[0])
);

// --------------------------------------------------------------------
// --------------------------- Cheat Engine ---------------------------
// --------------------------------------------------------------------

CODES codes (
	.clk        (clk_sys),
	.reset      (gg_reset),
	.enable     (gg_en),
	.addr_in    (cpu_addr),
	.data_in    (cpu_di),
	.available  (gg_available),
	.code       (gg_code),
	.genie_ovr  (genie_ovr),
	.genie_data (genie_data)
);

// --------------------------------------------------------------------
// --------------------- GBC/DMG mode KEY0 (GBC) ----------------------
// --------------------------------------------------------------------

assign SS_Top_BACK[56:55] = ff4c_key0;

// KEY0 FF4C CPU mode register
// Bits 2 and 3 CPU mode select
// 00: CGB mode (Mode used by carts supporting CGB)
// 01: DMG/MGB mode (Mode used by DMG/MGB-only carts)
 //10: PGB1 mode (STOP the CPU, with the LCD operated by an external signal)
// 11: PGB2 mode (CPU still running, with the LCD operated by an external signal)
// R/W only when boot rom is enabled
// https://forums.nesdev.org/viewtopic.php?t=19888
always @(posedge clk_sys) begin
	if(reset_ss) begin
		ff4c_key0 <= SS_Top[56:55]; // 2'd0;
	end else if(sel_key0 & ce_cpu & ~cpu_wr_n_edge) begin
		ff4c_key0 <= cpu_do[3:2];
	end
end

// --------------------------------------------------------------------
// --------------------- Speed Toggle KEY1 (GBC)-----------------------
// --------------------------------------------------------------------
assign speed = cpu_speed;

assign SS_Top_BACK[3] = cpu_speed;
assign SS_Top_BACK[4] = prepare_switch;

always @(posedge clk_sys) begin
   if(reset_ss) begin
		cpu_speed      <= SS_Top[3]; // 1'b0;
		prepare_switch <= SS_Top[4]; // 1'b0;
	end
	else if (ce_2x && sel_key1 && !cpu_wr_n_edge)begin
		prepare_switch <= cpu_do[0];
	end
	
	if (ce_2x && isGBC && prepare_switch && cpu_stop) begin
		cpu_speed <= !cpu_speed;
		prepare_switch <= 1'b0;
	end
end

// --------------------------------------------------------------------
// ------------------------------ audio -------------------------------
// --------------------------------------------------------------------

wire audio_rd = !cpu_rd_n && sel_audio;
wire audio_wr = !cpu_wr_n_edge && sel_audio;

gbc_snd audio (
	.clk				( clk_sys			),
	.ce            ( ce_2x           ),
	.reset			( reset_ss			),
	
	.is_gbc        ( isGBC           ),

	.s1_read  		( audio_rd  		),
	.s1_write 		( audio_wr  		),
	.s1_addr    	( cpu_addr[6:0]	),
   .s1_readdata 	( snd_d_out       ),
	.s1_writedata  ( snd_d_in       	),

   .snd_left 		( audio_l  			),
	.snd_right  	( audio_r  			),
	
  .SaveStateBus_Din  (SaveStateBus_Din ), 
  .SaveStateBus_Adr  (SaveStateBus_Adr ),
  .SaveStateBus_wren (SaveStateBus_wren),
  .SaveStateBus_rst  (SaveStateBus_rst ),
  .SaveStateBus_Dout (SaveStateBus_wired_or[5])
);

// --------------------------------------------------------------------
// -----------------------serial port()--------------------------------
// --------------------------------------------------------------------

// SNAC
wire serial_irq;

assign sc_int_clock2 = sc_shiftclock;

link link (
  .clk_sys(clk_sys),
  .ce(ce_cpu),
  .rst(reset_ss),

  .sel_sc(sel_sc),
  .sel_sb(sel_sb),
  .cpu_wr_n(cpu_wr_n_edge),
  .sc_start_in(cpu_do[7]),
  .sc_int_clock_in(cpu_do[0]),

  .sb_in(cpu_do),

  .serial_clk_in(serial_clk_in),
  .serial_data_in(serial_data_in),

  .serial_clk_out(serial_clk_out),
  .serial_data_out(serial_data_out),
  .sb(sb_o),
  .serial_irq(serial_irq),
  .sc_start(sc_start),
  .sc_int_clock(sc_shiftclock),
	
  .SaveStateBus_Din  (SaveStateBus_Din ), 
  .SaveStateBus_Adr  (SaveStateBus_Adr ),
  .SaveStateBus_wren (SaveStateBus_wren),
  .SaveStateBus_rst  (SaveStateBus_rst ),
  .SaveStateBus_Dout (SaveStateBus_wired_or[3])
);

// --------------------------------------------------------------------
// ------------------------------ inputs ------------------------------
// --------------------------------------------------------------------

reg  [1:0] p54;

assign SS_Top_BACK[6:5] = p54;

always @(posedge clk_sys) begin
	if(reset_ss) p54 <= SS_Top[6:5]; //2'b00 for DMG, 2'b11 for CGB/SGB will be written by BIOS
	else if(ce_cpu && sel_joy && !cpu_wr_n_edge)	p54 <= cpu_do[5:4];
end

assign joy_do = { 2'b11, p54, joy_din };
assign joy_p54 = p54;

// --------------------------------------------------------------------
// ------------------------------ unused regs -------------------------
// --------------------------------------------------------------------

assign SS_Top_BACK[34:27] = FF72;
assign SS_Top_BACK[42:35] = FF73;
assign SS_Top_BACK[50:43] = FF74;
assign SS_Top_BACK[53:51] = FF75;

always @(posedge clk_sys) begin
	if(reset_ss) begin
		FF72 <= SS_Top[34:27]; // 0;  
		FF73 <= SS_Top[42:35]; // 0;  
		FF74 <= SS_Top[50:43]; // 0;  
		FF75 <= SS_Top[53:51]; // 0;  
	end else if(ce_cpu && !cpu_wr_n_edge)	begin
		if (sel_FF72) FF72 <= cpu_do;
		if (sel_FF73) FF73 <= cpu_do;
		if (sel_FF74) FF74 <= cpu_do;
		if (sel_FF75) FF75 <= cpu_do[6:4];
	end
end

// --------------------------------------------------------------------
// ---------------------------- interrupts ----------------------------
// --------------------------------------------------------------------

// interrupt flags are set when the event happens or when the cpu writes
// the register to 1. The "highest" one active is cleared when the cpu
// runs an interrupt ack cycle or when it writes a 0 to the register

assign irq_ack = !cpu_iorq_n && !cpu_m1_n;

// irq vector
assign irq_vec = 
			if_r[0]&&ie_r[0]?8'h40:   // vsync
			if_r[1]&&ie_r[1]?8'h48:   // lcdc
			if_r[2]&&ie_r[2]?8'h50:   // timer
			if_r[3]&&ie_r[3]?8'h58:   // serial
			if_r[4]&&ie_r[4]?8'h60:   // input
			8'h00;

//wire vs = (lcd_mode == 2'b01);
//reg vsD, vsD2;
reg [3:0] inputD, inputD2;

// irq is low when an enable irq is active
assign irq_n = !(ie_r & if_r);

wire video_irq,vblank_irq;
wire timer_irq;

reg old_vblank_irq, old_video_irq, old_timer_irq, old_serial_irq;
reg old_ack = 0;

assign SS_Top_BACK[11: 7] = ie_r[4:0];
assign SS_Top_BACK[16:12] = if_r;
assign SS_Top_BACK[   17] = old_vblank_irq;
assign SS_Top_BACK[   18] = old_video_irq;
assign SS_Top_BACK[   19] = old_timer_irq;
assign SS_Top_BACK[   20] = old_serial_irq;
assign SS_Top_BACK[   21] = old_ack;
assign SS_Top_BACK[26:24] = ie_r[7:5];

always @(negedge clk_sys) begin //negedge to trigger interrupt earlier

	if(reset_ss) begin
		ie_r[4:0] 		 <= SS_Top[11: 7]; // 5'h00;
		if_r 			    <= SS_Top[16:12]; // 5'h00;
		old_vblank_irq  <= SS_Top[   17]; // 1'b0;
		old_video_irq   <= SS_Top[   18]; // 1'b0;
		old_timer_irq   <= SS_Top[   19]; // 1'b0;
		old_serial_irq  <= SS_Top[   20]; // 1'b0;
		old_ack         <= SS_Top[   21]; // 1'b0;
		ie_r[7:5] 		 <= SS_Top[26:24]; // 3'h00;
	end else if (ce_cpu) begin

		// "When an interrupt signal changes from low to high,
		//  then the corresponding bit in the IF register becomes set."
		old_vblank_irq <= vblank_irq;
		if(~old_vblank_irq & vblank_irq) if_r[0] <= 1'b1;
	
		// video irq already is a 1 clock event
		old_video_irq <= video_irq;
		if(~old_video_irq & video_irq) if_r[1] <= 1'b1;
		
		// timer_irq already is a 1 clock event
		old_timer_irq <= timer_irq;
		if(~old_timer_irq & timer_irq) if_r[2] <= 1'b1;
		
		// serial irq already is a 1 clock event
		old_serial_irq <= serial_irq;
		if(~old_serial_irq & serial_irq) if_r[3] <= 1'b1;
	
		// falling edge on any input line P10..P13
	
		inputD <= joy_din;
		inputD2 <= inputD;
		if(~inputD & inputD2) if_r[4] <= 1'b1;
	
		// cpu acknowledges irq. this clears the active irq with hte 
		// highest priority
		old_ack <= irq_ack;
		
		if(old_ack & ~irq_ack) begin
			if(if_r[0] && ie_r[0]) if_r[0] <= 1'b0;
			else if(if_r[1] && ie_r[1]) if_r[1] <= 1'b0;
			else if(if_r[2] && ie_r[2]) if_r[2] <= 1'b0;
			else if(if_r[3] && ie_r[3]) if_r[3] <= 1'b0;
			else if(if_r[4] && ie_r[4]) if_r[4] <= 1'b0;
		end
	
		// cpu writes interrupt enable register
		if(sel_ie && !cpu_wr_n_edge)
			ie_r <= cpu_do;
	
		// cpu writes interrupt flag register
		if(sel_if && !cpu_wr_n_edge)
			if_r <= cpu_do[4:0];
			
	end
end
			
// --------------------------------------------------------------------
// ------------------------------ timer -------------------------------
// --------------------------------------------------------------------

timer timer (
	.reset	    		 ( reset_ss      ),
	.clk_sys		       ( clk_sys       ),
	.ce                  ( ce_cpu        ), //2x in fast mode
		 
	.irq         		 ( timer_irq     ),
				 
	.cpu_sel     		 ( sel_timer     ),
	.cpu_addr    		 ( cpu_addr[1:0] ),
	.cpu_wr      		 ( !cpu_wr_n_edge ),
	.cpu_di      		 ( cpu_do        ),
	.cpu_do      		 ( timer_do      ),
	
	.SaveStateBus_Din  (SaveStateBus_Din ), 
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[1])
);
	
// --------------------------------------------------------------------
// ------------------------------ video -------------------------------
// --------------------------------------------------------------------

// cpu tries to read or write the lcd controller registers
wire [12:0] video_addr;
wire video_rd, dma_rd;

wire [7:0] dma_data = (isGBC & dma_sel_wram) ? wram_do :
                        dma_sel_ext_bus ? ext_bus_di :
                            dma_sel_vram ? (isGBC&vram_bank ? vram1_do : vram_do) :
                                8'hFF;

video video (
	.reset       ( reset_ss         ),
	.clk         ( clk_sys       ),
	.ce          ( ce            ),   // 4Mhz
	.ce_cpu      ( ce_cpu        ),   //can be 2x in cgb double speed mode
	.isGBC       ( isGBC         ),
	.isGBC_mode  ( isGBC_mode    ),  //enable GBC mode during bootstrap rom
	.megaduck    ( megaduck      ),

	.boot_rom_en ( boot_rom_enabled ),

	.irq         ( video_irq     ),
	.vblank_irq  ( vblank_irq    ),


	.cpu_sel_reg ( sel_video_reg ),
	.cpu_sel_oam ( sel_video_oam ),
	.cpu_addr    ( cpu_addr[7:0] ),
	.cpu_wr      ( !cpu_wr_n_edge ),
	.cpu_di      ( cpu_do        ),
	.cpu_do      ( video_do      ),
	
	.lcd_on      ( lcd_on        ),
	.lcd_clkena  ( lcd_clkena    ),
	.lcd_data    ( lcd_data      ),
	.lcd_data_gb ( lcd_data_gb   ),
	.mode        ( lcd_mode      ),
	.lcd_vsync   ( lcd_vsync     ),

	.oam_cpu_allow  ( oam_cpu_allow  ),
	.vram_cpu_allow ( vram_cpu_allow ),
	.vram_rd     ( video_rd      ),
	.vram_addr   ( video_addr    ),
	.vram_data   ( vram_do       ),
	
	// vram connection bank1 (GBC)
	.vram1_data  ( vram1_do      ),
	
	.dma_rd      ( dma_rd        ),
	.dma_addr    ( dma_addr      ),
	.dma_data    ( dma_data      ),
   
   .Savestate_OAMRAMAddr      (Savestate_RAMAddr[7:0]),
   .Savestate_OAMRAMRWrEn     (Savestate_RAMRWrEn[2]),
   .Savestate_OAMRAMWriteData (Savestate_RAMWriteData),
   .Savestate_OAMRAMReadData  (Savestate_RAMReadData_ORAM),
	
	.SaveStateBus_Din  (SaveStateBus_Din ), 
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[4])
);

// total 8k/16k (CGB) vram from $8000 to $9fff
wire cpu_wr_vram = sel_vram && !cpu_wr_n && vram_cpu_allow;

wire hdma_rd;

wire [7:0] vram_di = (hdma_read_wram_bus) ? wram_do :
                        (hdma_read_ext_bus) ? ext_bus_di :
                        cpu_do;

wire vram_wren = video_rd?1'b0:!vram_bank&&((hdma_rd&&isGBC)||cpu_wr_vram);
wire vram1_wren = video_rd?1'b0:vram_bank&&((hdma_rd&&isGBC)||cpu_wr_vram);

wire [15:0] hdma_target_addr;
wire [12:0] vram_addr = video_rd?video_addr:(hdma_rd&&isGBC)?hdma_target_addr[12:0]:(dma_rd&&dma_sel_vram)?dma_addr[12:0]:cpu_addr[12:0];

wire [7:0] Savestate_RAMReadData_VRAM0, Savestate_RAMReadData_VRAM1;

dpram #(13) vram0 (
	.clock_a   (clk_cpu  ),
	.address_a (vram_addr),
	.wren_a    (vram_wren),
	.data_a    (vram_di  ),
	.q_a       (vram_do  ),
	
	.clock_b   (clk_sys),
	.address_b (Savestate_RAMAddr[12:0]),
	.wren_b    (Savestate_RAMRWrEn[1] & !Savestate_RAMAddr[13]),
	.data_b    (Savestate_RAMWriteData),
	.q_b       (Savestate_RAMReadData_VRAM0)
);

//separate 8k for vbank1 for gbc because of BG reads
dpram #(13) vram1 (
	.clock_a   (clk_cpu   ),
	.address_a (vram_addr ),
	.wren_a    (vram1_wren),
	.data_a    (vram_di   ),
	.q_a       (vram1_do  ),
	
	.clock_b   (clk_sys),
	.address_b (Savestate_RAMAddr[12:0]),
	.wren_b    (Savestate_RAMRWrEn[1] & Savestate_RAMAddr[13]),
	.data_b    (Savestate_RAMWriteData),
	.q_b       (Savestate_RAMReadData_VRAM1)
);

assign Savestate_RAMReadData_VRAM = Savestate_RAMAddr[13] ? Savestate_RAMReadData_VRAM1 : Savestate_RAMReadData_VRAM0;

//GBC VRAM banking

assign SS_Top_BACK[22] = vram_bank;

always @(posedge clk_sys) begin
	if(reset_ss)
		vram_bank <= SS_Top[22]; // 1'd0;
	else if (ce_cpu) begin
		if((cpu_addr == 16'hff4f) && !cpu_wr_n_edge && isGBC)
			vram_bank <= cpu_do[0];
	end
end

// --------------------------------------------------------------------
// -------------------------- HDMA engine(GBC) ------------------------
// --------------------------------------------------------------------

hdma hdma(
	.reset	          ( reset_ss         ),
	.clk		          ( clk_sys       ),
	.ce                ( ce_cpu         ),
	.speed				 ( cpu_speed     ),
	
	// cpu register interface
	.sel_reg 	       ( sel_hdma      ),
	.addr			       ( cpu_addr[3:0] ),
	.wr			       ( !cpu_wr_n_edge   ),
	.dout			       ( hdma_do       ),
	.din               ( cpu_do        ),
	
	.lcd_mode          ( lcd_mode      ),
	
	// dma connection
	.hdma_rd           ( hdma_rd          ),
	.hdma_active       ( hdma_active      ),
	.hdma_source_addr  ( hdma_source_addr ),
	.hdma_target_addr  ( hdma_target_addr ),
	
	.SaveStateBus_Din  (SaveStateBus_Din ), 
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[2])
);

// --------------------------------------------------------------------
// -------------------------- zero page ram ---------------------------
// --------------------------------------------------------------------

// 127 bytes internal zero page ram from $ff80 to $fffe
wire cpu_wr_zpram = sel_zpram && !cpu_wr_n;

dpram #(7) zpram (
	.clock_a   (clk_cpu      ),
	.address_a (cpu_addr[6:0]),
	.wren_a    (cpu_wr_zpram ),
	.data_a    (cpu_do       ),
	.q_a       (zpram_do     ),
	
	.clock_b   (clk_sys),
	.address_b (Savestate_RAMAddr[6:0]),
	.wren_b    (Savestate_RAMRWrEn[3]),
	.data_b    (Savestate_RAMWriteData),
	.q_b       (Savestate_RAMReadData_ZRAM)
);

// --------------------------------------------------------------------
// -------------------------- 8k/32k(GBC) work ram  -------------------
// --------------------------------------------------------------------

// Separate WRAM bus on GBC.
wire hdma_read_wram_bus = (isGBC & hdma_rd & hdma_sel_wram);
wire dma_read_wram_bus = (dma_rd & dma_sel_wram);

wire wram_wren = ~isGBC ? (ext_bus_wram_sel & ext_bus_wr) :
                    (sel_wram & ~cpu_wr_n_edge & ~hdma_read_wram_bus & ~dma_read_wram_bus);

wire [12:0] wram_addr_i = ~isGBC ? ext_bus_addr[12:0] :
                            hdma_read_wram_bus ? hdma_source_addr[12:0] :
                                dma_read_wram_bus ? dma_addr[12:0] :
                                cpu_addr[12:0];

wire [14:0] wram_addr = (wram_addr_i[12]) ? { wram_bank, wram_addr_i[11:0] }  // bank 1-7 $D000-DFFF
                                          : {      3'd0, wram_addr_i[11:0] }; // bank 0   $C000-CFFF

dpram #(15) wram (
	.clock_a   (clk_cpu),
	.address_a (wram_addr),
	.wren_a    (wram_wren),
	.data_a    (cpu_do),
	.q_a       (wram_do),
	
	.clock_b   (clk_sys),
	.address_b (Savestate_RAMAddr[14:0]),
	.wren_b    (Savestate_RAMRWrEn[0]),
	.data_b    (Savestate_RAMWriteData),
	.q_b       (Savestate_RAMReadData_WRAM)
);

//GBC WRAM banking
assign SS_Top_BACK[2:0] = wram_bank;

always @(posedge clk_sys) begin
	if(reset_ss)
		wram_bank <= SS_Top[2:0]; // 3'd1;
	else if(ce_cpu && sel_wram_bank && !cpu_wr_n_edge) begin
		if (cpu_do[2:0]==3'd0) // 0 -> 1;
			wram_bank <= 3'd1;
		else
			wram_bank <= cpu_do[2:0];
	end
end

// --------------------------------------------------------------------
// ------------------------ internal boot rom -------------------------
// --------------------------------------------------------------------

// writing 01(GB) or 11(GBC) to $ff50 disables the internal rom

assign SS_Top_BACK[23] = boot_rom_enabled;

always @(posedge clk_sys) begin
	if(reset_ss)
		boot_rom_enabled <= SS_Top[23]; // 1'b1;
	else if (ce) begin 
		if((cpu_addr == 16'hff50) && !cpu_wr_n_edge)
          if ((isGBC && cpu_do[7:0]==8'h11) || (!isGBC && cpu_do[0]))
		          boot_rom_enabled <= 1'b0;
	end
end
			
// combine boot rom data with cartridge data

wire [15:0] boot_rom_addr = (isGBC && hdma_rd) ? hdma_source_addr : cpu_addr;

//  0- FF bootrom 1st part
//100-1FF Cart Header
//200-8FF bootrom 2nd part
assign sel_boot_rom_cgb = isGBC && (boot_rom_addr[15:8] >= 8'h02 && boot_rom_addr[15:8] <= 8'h08);
assign sel_boot_rom = boot_rom_enabled && (!boot_rom_addr[15:8] || sel_boot_rom_cgb) && ~megaduck;


// $000-8FF: GBC
// $900-9FF: DMG
// $A00-AFF: SGB
wire [11:0] boot_addr =
        isGBC ? boot_rom_addr[11:0] :
        isSGB ? { 4'hA, boot_rom_addr[7:0] } :
        { 4'h9, boot_rom_addr[7:0] };

wire boot_download = cgb_boot_download | dmg_boot_download | sgb_boot_download;
wire [10:0] boot_wr_addr =
        dmg_boot_download ? {4'h9, ioctl_addr[7:1] } :
        sgb_boot_download ? {4'hA, ioctl_addr[7:1] } :
        ioctl_addr[11:1];

wire [7:0] boot_q;

dpram_dif #(12,8,11,16,"BootROMs/cgb_boot.mif") boot_rom (
	.clock (clk_sys),

	.address_a (boot_addr),
	.q_a (boot_q),

	.address_b (boot_wr_addr),
	.wren_b (ioctl_wr && boot_download),
	.data_b (ioctl_dout)
);

reg [7:0] boot_do_gba;

always begin
	case (boot_addr)
		12'h0F2: boot_do_gba = 8'h00;
		12'h0F3: boot_do_gba = 8'h00;
		12'h0F5: boot_do_gba = 8'hCD;
		12'h0F6: boot_do_gba = 8'hD0;
		12'h0F7: boot_do_gba = 8'h05;
		12'h0F8: boot_do_gba = 8'hAF;
		12'h0F9: boot_do_gba = 8'hE0;
		12'h0FA: boot_do_gba = 8'h70;
		12'h0FB: boot_do_gba = 8'h04;
		12'h409: boot_do_gba = 8'h80;
		12'h40A: boot_do_gba = 8'hFF;
		default: boot_do_gba = boot_q;
	endcase
end

assign boot_do = (isGBC && boot_gba_en && real_cgb_boot) ? boot_do_gba : boot_q;
// --------------------------------------------------------------------
// ------------------ External bus (WRAM, Cartridge) ------------------
// --------------------------------------------------------------------

// Emulate cartridge open bus behavior.
// Some games read from Cart RAM while it is disabled or not present and
// expect to read the previous ROM byte instead of $FF otherwise they freeze.
// Ex. Tokyo Disneyland - Fantasy Tour (in Minnie's house) and
// Daiku no Gen-san - Kachikachi no Tonkachi ga Kachi (Stage 1-4)

reg [7:0] open_bus_data;
reg [2:0] open_bus_cnt;

assign SS_Top2_BACK[ 7: 0] = open_bus_data;
assign SS_Top2_BACK[10: 8] = open_bus_cnt;

always @(posedge clk_sys) begin
	if(reset_ss) begin
		open_bus_data <= SS_Top2[ 7: 0]; // 8'd0;
		open_bus_cnt  <= SS_Top2[10: 8]; // 3'd0;
	end else if (ce) begin
		open_bus_data <= ext_bus_di;
		if ( (~isGBC & ext_bus_wram_sel) | (cart_sel & cart_oe) ) begin
			open_bus_cnt <= 0;
		end else if (~&open_bus_cnt) begin
			open_bus_cnt <= open_bus_cnt + 1'b1;
			if (open_bus_cnt == 3'd4) open_bus_data <= 8'hFF; // Slow pull-up
		end
	end
end

assign cart_di = cpu_do;

wire hdma_read_ext_bus = (isGBC & hdma_rd & hdma_sel_ext_bus);
wire dma_read_ext_bus = (dma_rd & dma_sel_ext_bus);

assign nCS = ~( hdma_read_ext_bus ? hdma_sel_cram : dma_read_ext_bus ? dma_sel_ext_ram : (sel_cram | sel_wram) );

wire [15:0] ext_bus_i = hdma_read_ext_bus ? hdma_source_addr : dma_read_ext_bus ? dma_addr : cpu_addr;

// External A15 is not directly connected to internal A15. It does not go low when accessing the boot rom.
assign ext_bus_a15 = ext_bus_i[15] | sel_boot_rom;
assign ext_bus_addr = ext_bus_i[14:0];

assign ext_bus_rd = hdma_read_ext_bus | dma_read_ext_bus | (sel_ext_bus & ~cpu_rd_n);
assign ext_bus_wr = (sel_ext_bus & ~cpu_wr_n_edge) & ~hdma_read_ext_bus & ~dma_read_ext_bus;

assign ext_bus_wram_sel = ~nCS &  ext_bus_addr[14];
assign ext_bus_cram_sel = ~nCS & ~ext_bus_addr[14];
assign ext_bus_rom_sel  = ~ext_bus_a15;

assign ext_bus_di = (~isGBC & ext_bus_wram_sel) ? wram_do :
                        (cart_sel & cart_oe) ? cart_do : open_bus_data;

assign cart_sel = ext_bus_rom_sel | ext_bus_cram_sel;
assign cart_rd = cart_sel & ext_bus_rd;
assign cart_wr = cart_sel & ext_bus_wr;

assign DMA_on = cart_sel & (hdma_active | dma_rd);

// --------------------------------------------------------------------
// ------------------------ savestates -------------------------
// --------------------------------------------------------------------

wire savestate_savestate;
wire savestate_loadstate;
wire [31:0] savestate_address;
wire savestate_busy;
wire savestate_loaded;

assign SaveStateExt_Din  = SaveStateBus_Din;
assign SaveStateExt_Adr  = SaveStateBus_Adr;
assign SaveStateExt_wren = SaveStateBus_wren;
assign SaveStateExt_rst  = SaveStateBus_rst;
assign SaveStateExt_load = savestate_loaded;

assign Savestate_CRAMAddr      = Savestate_RAMAddr;    
assign Savestate_CRAMRWrEn     = Savestate_RAMRWrEn[4];
assign Savestate_CRAMWriteData = Savestate_RAMWriteData;

wire [63:0] SaveStateBus_Dout  = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1] | SaveStateBus_wired_or[2] | SaveStateBus_wired_or[3] |
                                 SaveStateBus_wired_or[4] | SaveStateBus_wired_or[5] | SaveStateBus_wired_or[6] | SaveStateBus_wired_or[7] |
                                 SaveStateExt_Dout;
 
wire sleep_rewind, sleep_savestates;
 
gb_savestates gb_savestates (
   .clk                    (clk_sys),
   .reset_in               (reset_r),
   .reset_out              (reset_ss),
   
   .load_done              (savestate_loaded),
   
   .increaseSSHeaderCount  (increaseSSHeaderCount),
   .save                   (savestate_savestate),
   .load                   (savestate_loadstate),
   .savestate_address      (savestate_address),
   .savestate_busy         (savestate_busy),      
   
   .cart_ram_size          (cart_ram_size),
   
   .lcd_vsync              (lcd_vsync),
   
   .BUS_Din                (SaveStateBus_Din), 
   .BUS_Adr                (SaveStateBus_Adr), 
   .BUS_wren               (SaveStateBus_wren), 
   .BUS_rst                (SaveStateBus_rst), 
   .BUS_Dout               (SaveStateBus_Dout),
      
   //.loading_savestate      (loading_savestate),
   //.saving_savestate       (saving_savestate),
   .sleep_savestate        (sleep_savestates),
   .clock_ena_in           (ce_2x),
   
   .Save_RAMAddr           (Savestate_RAMAddr),     
   .Save_RAMWrEn           (Savestate_RAMRWrEn),           
   .Save_RAMWriteData      (Savestate_RAMWriteData),   
   .Save_RAMReadData_WRAM  (Savestate_RAMReadData_WRAM),
   .Save_RAMReadData_VRAM  (Savestate_RAMReadData_VRAM),
   .Save_RAMReadData_ORAM  (Savestate_RAMReadData_ORAM),
   .Save_RAMReadData_ZRAM  (Savestate_RAMReadData_ZRAM),
   .Save_RAMReadData_CRAM  (Savestate_CRAMReadData),
            
   .bus_out_Din            (SAVE_out_Din),   
   .bus_out_Dout           (SAVE_out_Dout),  
   .bus_out_Adr            (SAVE_out_Adr),   
   .bus_out_rnw            (SAVE_out_rnw),   
   .bus_out_ena            (SAVE_out_ena),   
   .bus_out_be             (SAVE_out_be),   
   .bus_out_done           (SAVE_out_done)  
);

gb_statemanager #(58720256, 33554432) gb_statemanager (
   .clk                 (clk_sys),
   .reset               (reset_r),

   .rewind_on           (rewind_on),    
   .rewind_active       (rewind_active),

   .savestate_number    (savestate_number),
   .save                (save_state),
   .load                (load_state),

   .sleep_rewind        (sleep_rewind),
   .vsync               (lcd_vsync),       

   .request_savestate   (savestate_savestate),
   .request_loadstate   (savestate_loadstate),
   .request_address     (savestate_address),  
   .request_busy        (savestate_busy)     
);

assign sleep_savestate = sleep_rewind | sleep_savestates;


endmodule
