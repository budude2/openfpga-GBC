`default_nettype none

module gb_top
(
	input logic clk_sys,
	input logic clk_ram,
  input logic reset,
  input logic pll_core_locked_s,

  input logic ioctl_download,
  input logic ioctl_upload,
  input logic [24:0] ioctl_addr,
  input logic [15:0] ioctl_dout,
  input logic ioctl_wr,


	);

logic boot_download, cart_download, palette_download, sgb_border_download, cgb_boot_download, dmg_boot_download, sgb_boot_download;

always_comb begin
  cart_download       = 0;
  sgb_border_download = 0;
  palette_download    = 0;
  cgb_boot_download   = 0;
  dmg_boot_download   = 0;
  sgb_boot_download   = 0;

  if(ioctl_download) begin
    case (dataslot_requestwrite_id)
      1: begin cart_download        = 1'b1; end
      2: begin sgb_border_download  = 1'b1; end
      3: begin palette_download     = 1'b1; end
      4: begin cgb_boot_download    = 1'b1; end
      5: begin dmg_boot_download    = 1'b1; end
      6: begin sgb_boot_download    = 1'b1; end
    endcase
  end

  boot_download  = cgb_boot_download | dmg_boot_download | sgb_boot_download;
end

logic [14:0] cart_addr;
logic [22:0] mbc_addr;
logic cart_a15, cart_rd, cart_wr, cart_oe, nCS;
logic [7:0] cart_di, cart_do;

wire  [1:0] sdram_ds     =  cart_download ? 2'b11 : {mbc_addr[0], ~mbc_addr[0]};
wire [15:0] sdram_do;
wire [15:0] sdram_di     =  cart_download ? ioctl_dout : 16'd0;
wire [23:0] sdram_addr   =  cart_download ? ioctl_addr[24:1] : {2'b00, mbc_addr[22:1]};
wire sdram_oe            = ~cart_download & cart_rd & ~cram_rd;
wire sdram_we            =  cart_download & dn_write;
wire sdram_refresh_force;
wire sdram_autorefresh   = !ff_on;

assign dram_cke = 1;

sdram sdram (
 // interface to the MT48LC16M16 chip
 .sd_data        ( dram_dq                ),
 .sd_addr        ( dram_a                 ),
 .sd_dqm         ( dram_dqm               ),
 .sd_cs          (                        ),
 .sd_ba          ( dram_ba                ),
 .sd_we          ( dram_we_n              ),
 .sd_ras         ( dram_ras_n             ),
 .sd_cas         ( dram_cas_n             ),
 .sd_clk         ( dram_clk               ),

  // system interface
 .clk            ( clk_ram                ),
 .sync           ( ce_cpu2x               ),
 .init           ( ~pll_core_locked_s     ),

 // cpu interface
 .din            ( sdram_di               ),
 .addr           ( sdram_addr             ),
 .ds             ( sdram_ds               ),
 .we             ( sdram_we               ),
 .oe             ( sdram_oe               ),
 .autorefresh    ( sdram_autorefresh      ),
 .refresh        ( sdram_refresh_force    ),
 .dout           ( sdram_do               )
);

wire dn_write;
wire cart_ready;
wire cram_rd, cram_wr;
wire [7:0] rom_do = (mbc_addr[0]) ? sdram_do[15:8] : sdram_do[7:0];
wire [7:0] ram_mask_file, cart_ram_size;
wire isGBC_game, isSGB_game;
wire cart_has_save;
wire [31:0] RTC_timestampOut;
wire [47:0] RTC_savedtimeOut;
wire rumbling;
wire RTC_inuse;

rumbler rumbler_module
(
  .clk          ( clk_sys             ),
  .reset        ( reset               ),
  .rumble_en    ( rumble_en           ),
  .rumbling     ( rumbling            ),
  .cart_wr      ( cart_tran_bank0[6]  ),
  .cart_rumble  ( cart_tran_bank3[1]  )
);

reg ce_32k; // 32768Hz clock for RTC
reg [9:0] ce_32k_div;
always_ff @(posedge clk_sys) begin
  ce_32k_div  <=  ce_32k_div + 1'b1;
  ce_32k      <= !ce_32k_div;
end

wire sram_wipe_done, sram_wipe_done_s;

cart_top cart
(
  .reset                      ( reset             ),
  .sram_rst                   ( ~pll_core_locked_s  ),
  .sram_wipe_done             ( sram_wipe_done    ),

  .clk_sys                    ( clk_sys           ),
  .ce_cpu                     ( ce_cpu            ),
  .ce_cpu2x                   ( ce_cpu2x          ),
  .speed                      ( speed             ),
  .megaduck                   ( 0                 ),
  .mapper_sel                 ( 0                 ),

  .cart_addr                  ( cart_addr         ),
  .cart_a15                   ( cart_a15          ),
  .cart_rd                    ( cart_rd           ),
  .cart_wr                    ( cart_wr           ),
  .cart_do                    ( cart_do           ),
  .cart_di                    ( cart_di           ),
  .cart_oe                    ( cart_oe           ),

  .nCS                        ( nCS               ),

  .mbc_addr                   ( mbc_addr          ),

  .dn_write                   ( dn_write          ),
  .cart_ready                 ( cart_ready        ),

  .cram_rd                    ( cram_rd           ),
  .cram_wr                    ( cram_wr           ),

  .cart_download              ( cart_download     ),

  .ram_mask_file              ( ram_mask_file     ),
  .ram_size                   ( cart_ram_size     ),
  .has_save                   ( cart_has_save     ),

  .isGBC_game                 ( isGBC_game        ),
  .isSGB_game                 ( isSGB_game        ),

  .ioctl_download             ( ioctl_download    ),
  .ioctl_upload               ( ioctl_upload      ),
  .ioctl_wr                   ( ioctl_wr          ),
  .ioctl_addr                 ( ioctl_addr        ),
  .ioctl_dout                 ( ioctl_dout        ),
  .ioctl_wait                 (                   ),

  .bk_wr                      ( bk_wr             ),
  .bk_rtc_wr                  ( bk_rtc_wr         ),
  .bk_addr                    ( bk_addr           ),
  .bk_data                    ( bk_data           ),
  .bk_q                       ( bk_q              ),
  .img_size                   ( loaded_save_size  ),

  .rom_di                     ( rom_do            ),

  .joystick_analog_0          ( 0                 ),

  .ce_32k                     ( ce_32k            ),
  .RTC_time                   ( rtc_data_s ),
  .RTC_timestampOut           ( RTC_timestampOut  ),
  .RTC_savedtimeOut           ( RTC_savedtimeOut  ),
  .RTC_inuse                  ( RTC_inuse ),

  .SaveStateExt_Din           ( 0                 ),
  .SaveStateExt_Adr           ( 0                 ),
  .SaveStateExt_wren          ( 0                 ),
  .SaveStateExt_rst           ( 0                 ),
  .SaveStateExt_Dout          (                   ),
  .savestate_load             ( 0                 ),
  .sleep_savestate            ( sleep_savestate   ),

  .Savestate_CRAMAddr         ( 0                 ),
  .Savestate_CRAMRWrEn        ( 0                 ),
  .Savestate_CRAMWriteData    ( 0                 ),
  .Savestate_CRAMReadData     (                   ),
  
  .rumbling                   ( rumbling          ),

  // SRAM External Interface
  .sram_addr                  ( sram_a            ), //! Address Out
  .sram_dq                    ( sram_dq           ), //! Data In/Out
  .sram_oe_n                  ( sram_oe_n         ), //! Output Enable
  .sram_we_n                  ( sram_we_n         ), //! Write Enable
  .sram_ub_n                  ( sram_ub_n         ), //! Upper Byte Mask
  .sram_lb_n                  ( sram_lb_n         )  //! Lower Byte Mask
);

reg [127:0] palette = 128'h828214517356305A5F1A3B4900000000;

always_ff @(posedge clk_sys) begin
  if (palette_download & ioctl_wr) begin
    palette[127:0] <= {palette[111:0], ioctl_dout[7:0], ioctl_dout[15:8]};
  end
end

wire lcd_clkena;
wire [14:0] lcd_data;
wire [1:0] lcd_mode;
wire [1:0] lcd_data_gb;
wire lcd_on;
wire lcd_vsync;

wire DMA_on;

wire reset = (~reset_n_s | (external_reset_s & loading_done) | cart_download | boot_download);
wire speed;

wire [15:0] GB_AUDIO_L;
wire [15:0] GB_AUDIO_R;

wire sc_int_clock_out, ser_clk_out, ser_clk_in;

always_comb begin
  port_tran_so_dir  = 1'b1;
  port_tran_si_dir  = 1'b0;
  ser_clk_in        = port_tran_sck;
  port_tran_sck_dir = sc_int_clock_out;

  if (sc_int_clock_out) begin
    port_tran_sck = ser_clk_out;
  end else begin
    port_tran_sck = 1'bZ;
  end                   
end

// the gameboy itself
gb gb
(
  .reset                  ( reset | ~loading_done ),
  
  .clk_sys                ( clk_sys               ),
  .ce                     ( ce_cpu                ),   // the whole gameboy runs on 4mhnz
  .ce_2x                  ( ce_cpu2x              ),   // ~8MHz in dualspeed mode (GBC)
  
  .isGBC                  ( isGBC                 ),
  .real_cgb_boot          ( 1                     ),  
  .isSGB                  ( sgb_en & ~isGBC       ),
  .megaduck               ( 0                     ),

  .joy_p54                ( joy_p54               ),
  .joy_din                ( joy_do_sgb            ),

  // interface to the "external" game cartridge
  .ext_bus_addr           ( cart_addr             ),
  .ext_bus_a15            ( cart_a15              ),
  .cart_rd                ( cart_rd               ),
  .cart_wr                ( cart_wr               ),
  .cart_do                ( cart_do               ),
  .cart_di                ( cart_di               ),
  .cart_oe                ( cart_oe               ),

  .nCS                    ( nCS                   ),

  .boot_gba_en            ( gba_en                ),
  .fast_boot_en           ( 0                     ),

  .cgb_boot_download      ( cgb_boot_download     ),
  .dmg_boot_download      ( dmg_boot_download     ),
  .sgb_boot_download      ( sgb_boot_download     ),
  .ioctl_wr               ( ioctl_wr              ),
  .ioctl_addr             ( ioctl_addr            ),
  .ioctl_dout             ( ioctl_dout            ),

  // audio
  .audio_l                ( GB_AUDIO_L            ),
  .audio_r                ( GB_AUDIO_R            ),
  
  // interface to the lcd
  .lcd_clkena             ( lcd_clkena            ),
  .lcd_data               ( lcd_data              ),
  .lcd_data_gb            ( lcd_data_gb           ),
  .lcd_mode               ( lcd_mode              ),
  .lcd_on                 ( lcd_on                ),
  .lcd_vsync              ( lcd_vsync             ),
  
  .speed                  ( speed                 ),
  .DMA_on                 ( DMA_on                ),
  
  // serial port
  .sc_int_clock2          ( sc_int_clock_out      ),
  .serial_clk_in          ( ser_clk_in            ),
  .serial_data_in         ( port_tran_si          ),
  .serial_clk_out         ( ser_clk_out           ),
  .serial_data_out        ( port_tran_so          ),
  
  // Palette download will disable cheats option (HPS doesn't distinguish downloads),
  // so clear the cheats and disable second option (chheats enable/disable)
  .gg_reset               ( 0                     ),
  .gg_en                  ( 0                     ),
  .gg_code                ( 0                     ),
  .gg_available           (                       ),
  
  // savestates
  .increaseSSHeaderCount  ( 0                     ),
  .cart_ram_size          ( 0                     ),
  .save_state             ( 0                     ),
  .load_state             ( 0                     ),
  .savestate_number       ( 0                     ),
  .sleep_savestate        ( sleep_savestate       ),

  .SaveStateExt_Din       (                       ),
  .SaveStateExt_Adr       (                       ),
  .SaveStateExt_wren      (                       ),
  .SaveStateExt_rst       (                       ),
  .SaveStateExt_Dout      ( 0                     ),
  .SaveStateExt_load      (                       ),
  
  .Savestate_CRAMAddr     (                       ),
  .Savestate_CRAMRWrEn    (                       ),
  .Savestate_CRAMWriteData(                       ),
  .Savestate_CRAMReadData ( 0                     ),
  
  .SAVE_out_Din           (                       ),  // data read from savestate
  .SAVE_out_Dout          ( 0                     ),  // data written to savestate
  .SAVE_out_Adr           (                       ),  // all addresses are DWORD addresses!
  .SAVE_out_rnw           (                       ),  // read = 1, write = 0
  .SAVE_out_ena           (                       ),  // one cycle high for each action
  .SAVE_out_be            (                       ),            
  .SAVE_out_done          ( 0                     ),  // should be one cycle high when write is done or read value is valid
  
  .rewind_on              ( 0                     ),
  .rewind_active          ( 0                     )
);

// Sound

wire [15:0] audio_l, audio_r;

assign audio_l = (fast_forward && ~ff_snd_en) ? 16'd0 : GB_AUDIO_L;
assign audio_r = (fast_forward && ~ff_snd_en) ? 16'd0 : GB_AUDIO_R;

// the lcd to vga converter
wire ce_pix;
wire [8:0] h_cnt, v_cnt;
wire h_end;

lcd lcd
(
  // serial interface
  .clk_sys        ( clk_sys                 ),
  .ce             ( ce_cpu                  ),

  .lcd_clkena     ( sgb_lcd_clkena          ),
  .data           ( sgb_lcd_data            ),
  .mode           ( sgb_lcd_mode            ),  // used to detect begin of new lines and frames
  .on             ( sgb_lcd_on              ),
  .lcd_vs         ( sgb_lcd_vsync           ),
  .shadow         ( 0                       ),

  .isGBC          ( isGBC                   ),

  .tint           ( |tint & ~bw_en          ),
  .inv            ( 0                       ),
  .originalcolors ( originalcolors          ),
  .analog_wide    ( 0                       ),

  // Palettes
  .pal1           ( palette[127:104]        ),
  .pal2           ( palette[103:80]         ),
  .pal3           ( palette[79:56]          ),
  .pal4           ( palette[55:32]          ),

  .sgb_border_pix ( sgb_border_pix          ),
  .sgb_pal_en     ( sgb_pal_en              ),
  .sgb_en         ( sgb_border_en & sgb_en  ),
  .sgb_freeze     ( sgb_lcd_freeze          ),

  .clk_vid        ( clk_ram                 ),
  .hs             ( video_hs_gb             ),
  .vs             ( video_vs_gb             ),
  .hbl            ( h_blank                 ),
  .vbl            ( v_blank                 ),
  .r              ( video_rgb_gb[23:16]     ),
  .g              ( video_rgb_gb[15:8]      ),
  .b              ( video_rgb_gb[7:0]       ),
  .ce_pix         ( ce_pix                  ),
  .h_cnt          ( h_cnt                   ),
  .v_cnt          ( v_cnt                   ),
  .h_end          ( h_end                   )
);

wire [1:0] joy_p54;
wire [3:0] joy_do_sgb;
wire [14:0] sgb_lcd_data;
wire [15:0] sgb_border_pix;
wire sgb_lcd_clkena, sgb_lcd_on, sgb_lcd_vsync, sgb_lcd_freeze;
wire [1:0] sgb_lcd_mode;
wire sgb_pal_en;

wire [7:0] joystick_0 = {cont1_key_s[15], cont1_key_s[14], cont1_key_s[5], cont1_key_s[4], cont1_key_s[0], cont1_key_s[1], cont1_key_s[2], cont1_key_s[3]};
wire [7:0] joystick_1 = {cont2_key_s[15], cont2_key_s[14], cont2_key_s[5], cont2_key_s[4], cont2_key_s[0], cont2_key_s[1], cont2_key_s[2], cont2_key_s[3]};
wire [7:0] joystick_2 = {cont3_key_s[15], cont3_key_s[14], cont3_key_s[5], cont3_key_s[4], cont3_key_s[0], cont3_key_s[1], cont3_key_s[2], cont3_key_s[3]};
wire [7:0] joystick_3 = {cont4_key_s[15], cont4_key_s[14], cont4_key_s[5], cont4_key_s[4], cont4_key_s[0], cont4_key_s[1], cont4_key_s[2], cont4_key_s[3]};

sgb sgb (
  .reset              ( reset | ~loading_done         ),
  .clk_sys            ( clk_sys                       ),
  .ce                 ( ce_cpu                        ),

  .clk_vid            ( clk_ram                       ),
  .ce_pix             ( ce_pix                        ),

  .joystick_0         ( joystick_0                    ),
  .joystick_1         ( joystick_1                    ),
  .joystick_2         ( joystick_2                    ),
  .joystick_3         ( joystick_3                    ),
  .joy_p54            ( joy_p54                       ),
  .joy_do             ( joy_do_sgb                    ),

  .sgb_en             ( sgb_en & isSGB_game & ~isGBC  ),
  .tint               ( tint[1] & ~bw_en              ),
  .isGBC_game         ( isGBC & isGBC_game            ),

  .lcd_on             ( lcd_on                        ),
  .lcd_clkena         ( lcd_clkena                    ),
  .lcd_data           ( lcd_data                      ),
  .lcd_data_gb        ( lcd_data_gb                   ),
  .lcd_mode           ( lcd_mode                      ),
  .lcd_vsync          ( lcd_vsync                     ),

  .h_cnt              ( h_cnt                         ),
  .v_cnt              ( v_cnt                         ),
  .h_end              ( h_end                         ),

  .border_download    ( sgb_border_download           ),
  .ioctl_wr           ( ioctl_wr                      ),
  .ioctl_addr         ( ioctl_addr                    ),
  .ioctl_dout         ( ioctl_dout                    ),

  .sgb_border_pix     ( sgb_border_pix                ),
  .sgb_pal_en         ( sgb_pal_en                    ),
  .sgb_lcd_data       ( sgb_lcd_data                  ),
  .sgb_lcd_on         ( sgb_lcd_on                    ),
  .sgb_lcd_freeze     ( sgb_lcd_freeze                ),
  .sgb_lcd_clkena     ( sgb_lcd_clkena                ),
  .sgb_lcd_mode       ( sgb_lcd_mode                  ),
  .sgb_lcd_vsync      ( sgb_lcd_vsync                 )
);

//////////////////////////////// CE ////////////////////////////////////

wire ce_cpu, ce_cpu2x;
wire cart_act     = cart_wr | cart_rd;
wire fastforward  = ff_en && cont1_key_s[9] && !ioctl_download;
wire ff_on;
wire sleep_savestate;
reg paused;

always_ff @(posedge clk_sys) begin
  paused <= sleep_savestate;
end

speedcontrol speedcontrol
(
  .clk_sys     ( clk_sys              ),
  .pause       ( paused               ),
  .speedup     ( fast_forward         ),
  .cart_act    ( cart_act             ),
  .DMA_on      ( DMA_on               ),
  .ce          ( ce_cpu               ),
  .ce_2x       ( ce_cpu2x             ),
  .refresh     ( sdram_refresh_force  ),
  .ff_on       ( ff_on                )
);

///////////////////////////// Fast Forward Latch /////////////////////////////////

reg fast_forward;
reg ff_latch;

always_ff @(posedge clk_sys) begin : ffwd
  reg last_ffw;
  reg ff_was_held;
  longint ff_count;

  last_ffw <= fastforward;

  if (fastforward)
    ff_count <= ff_count + 1;

  if (~last_ffw & fastforward) begin
    ff_latch <= 0;
    ff_count <= 0;
  end

  if ((last_ffw & ~fastforward)) begin // 32mhz clock, 0.2 seconds
    ff_was_held <= 0;

    if (ff_count < 4800000 && ~ff_was_held) begin
      ff_was_held <= 1;
      ff_latch    <= 1;
    end
  end

  fast_forward <= (fastforward | ff_latch);
end

endmodule