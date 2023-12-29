//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1 

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable, 

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,
 
///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus 

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,
    
output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
// 
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
//   [31:28] type
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [31:0]  cont1_key,
input   wire    [31:0]  cont2_key,
input   wire    [31:0]  cont3_key,
input   wire    [31:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig
    
);

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// cart is unused, so set all level translators accordingly
// directions are 0:IN, 1:OUT
assign cart_tran_bank3         = 8'hzz;
assign cart_tran_bank3_dir     = 1'b0;
assign cart_tran_bank2         = 8'hzz;
assign cart_tran_bank2_dir     = 1'b0;
assign cart_tran_bank1         = 8'hzz;
assign cart_tran_bank1_dir     = 1'b0;
assign cart_tran_bank0         = 4'hf;
assign cart_tran_bank0_dir     = 1'b1;
assign cart_tran_pin30         = 1'b0;      // reset or cs2, we let the hw control it by itself
assign cart_tran_pin30_dir     = 1'bz;
assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
assign cart_tran_pin31         = 1'bz;      // input
assign cart_tran_pin31_dir     = 1'b0;  // input

// link port is unused, set to input only to be safe
// each bit may be bidirectional in some applications
assign port_tran_so      = 1'bz;
assign port_tran_so_dir  = 1'b0;     // SO is output only
assign port_tran_si      = 1'bz;
assign port_tran_si_dir  = 1'b0;     // SI is input only
assign port_tran_sck     = 1'bz;
assign port_tran_sck_dir = 1'b0;    // clock direction can change
assign port_tran_sd      = 1'bz;
assign port_tran_sd_dir  = 1'b0;     // SD is input and not used

// tie off the rest of the pins we are not using
assign cram0_a     = 'h0;
assign cram0_dq    = {16{1'bZ}};
assign cram0_clk   = 0;
assign cram0_adv_n = 1;
assign cram0_cre   = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n  = 1;
assign cram0_we_n  = 1;
assign cram0_ub_n  = 1;
assign cram0_lb_n  = 1;

assign cram1_a     = 'h0;
assign cram1_dq    = {16{1'bZ}};
assign cram1_clk   = 0;
assign cram1_adv_n = 1;
assign cram1_cre   = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n  = 1;
assign cram1_we_n  = 1;
assign cram1_ub_n  = 1;
assign cram1_lb_n  = 1;

assign sram_a      = 'h0;
assign sram_dq     = {16{1'bZ}};
assign sram_oe_n   = 1;
assign sram_we_n   = 1;
assign sram_ub_n   = 1;
assign sram_lb_n   = 1;

assign dbg_tx      = 1'bZ;
assign user1       = 1'bZ;
assign aux_scl     = 1'bZ;
assign vpll_feed   = 1'bZ;


// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always @(*) begin
    casex(bridge_addr)
    default: begin
        bridge_rd_data <= 0;
    end
    32'h10xxxxxx: begin
        // example
        // bridge_rd_data <= example_device_data;
        bridge_rd_data <= 0;
    end
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end

reg [2:0] mapper_sel;
reg [31:0] reset_delay = 0;
reg rumble_en;
reg [1:0] sys_type;
reg ff_snd_en;
reg [1:0] tint;
reg [1:0] sgb_en;
reg sgc_gbc_en;
reg rw_en;

always @(posedge clk_74a) begin
    if (reset_delay > 0) begin
      reset_delay <= reset_delay - 1;
    end

    if (bridge_wr) begin
      casex (bridge_addr)
        32'h050: begin
          reset_delay <= 32'h100000;
        end
        // 32'h054: begin
        //   region <= bridge_wr_data[1:0];
        // end
        32'h200: begin
          mapper_sel <= bridge_wr_data[2:0];
        end
        32'h204: begin
          rumble_en <= bridge_wr_data[0];
        end
        32'h208: begin
          sys_type <= bridge_wr_data[1:0];
        end
        32'h20C: begin
          ff_snd_en <= bridge_wr_data[0];
        end
        32'h210: begin
          tint <= bridge_wr_data[1:0];
        end
        32'h214: begin
          sgb_en <= bridge_wr_data[1:0];
        end
        32'h218: begin
          sgc_gbc_en <= bridge_wr_data[0];
        end
        32'h21C: begin
          rw_en <= bridge_wr_data[0];
        end
      endcase
    end
end

//
// host/target command handler
//
    wire            reset_n;                // driven by host commands, can be used as core-wide reset
    wire    [31:0]  cmd_bridge_rd_data;
    
// bridge host commands
// synchronous to clk_74a
    wire            status_boot_done = pll_core_locked_s; 
    wire            status_setup_done = pll_core_locked_s; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire    [31:0]  dataslot_requestwrite_size;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_update;
    wire    [15:0]  dataslot_update_id;
    wire    [31:0]  dataslot_update_size;
    
    wire            dataslot_allcomplete;

    wire     [31:0] rtc_epoch_seconds;
    wire     [31:0] rtc_date_bcd;
    wire     [31:0] rtc_time_bcd;
    wire            rtc_valid;

    wire            savestate_supported;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;
    
    wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a

    reg             target_dataslot_read;       
    reg             target_dataslot_write;
    reg             target_dataslot_getfile;    // require additional param/resp structs to be mapped
    reg             target_dataslot_openfile;   // require additional param/resp structs to be mapped
    
    wire            target_dataslot_ack;        
    wire            target_dataslot_done;
    wire    [2:0]   target_dataslot_err;

    reg     [15:0]  target_dataslot_id;
    reg     [31:0]  target_dataslot_slotoffset;
    reg     [31:0]  target_dataslot_bridgeaddr;
    reg     [31:0]  target_dataslot_length;
    
    wire    [31:0]  target_buffer_param_struct; // to be mapped/implemented when using some Target commands
    wire    [31:0]  target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands
    
// bridge data slot access
// synchronous to clk_74a

    wire    [9:0]   datatable_addr;
    wire            datatable_wren;
    wire    [31:0]  datatable_data;
    wire    [31:0]  datatable_q;

core_bridge_cmd icb (

    .clk                        ( clk_74a                    ),
    .reset_n                    ( reset_n                    ),

    .bridge_endian_little       ( bridge_endian_little       ),
    .bridge_addr                ( bridge_addr                ),
    .bridge_rd                  ( bridge_rd                  ),
    .bridge_rd_data             ( cmd_bridge_rd_data         ),
    .bridge_wr                  ( bridge_wr                  ),
    .bridge_wr_data             ( bridge_wr_data             ),
    
    .status_boot_done           ( status_boot_done           ),
    .status_setup_done          ( status_setup_done          ),
    .status_running             ( status_running             ),

    .dataslot_requestread       ( dataslot_requestread       ),
    .dataslot_requestread_id    ( dataslot_requestread_id    ),
    .dataslot_requestread_ack   ( dataslot_requestread_ack   ),
    .dataslot_requestread_ok    ( dataslot_requestread_ok    ),

    .dataslot_requestwrite      ( dataslot_requestwrite      ),
    .dataslot_requestwrite_id   ( dataslot_requestwrite_id   ),
    .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
    .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack  ),
    .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok   ),

    .dataslot_update            ( dataslot_update            ),
    .dataslot_update_id         ( dataslot_update_id         ),
    .dataslot_update_size       ( dataslot_update_size       ),
    
    .dataslot_allcomplete       ( dataslot_allcomplete       ),

    .rtc_epoch_seconds          ( rtc_epoch_seconds          ),
    .rtc_date_bcd               ( rtc_date_bcd               ),
    .rtc_time_bcd               ( rtc_time_bcd               ),
    .rtc_valid                  ( rtc_valid                  ),
    
    .savestate_supported        ( savestate_supported        ),
    .savestate_addr             ( savestate_addr             ),
    .savestate_size             ( savestate_size             ),
    .savestate_maxloadsize      ( savestate_maxloadsize      ),

    .savestate_start            ( savestate_start            ),
    .savestate_start_ack        ( savestate_start_ack        ),
    .savestate_start_busy       ( savestate_start_busy       ),
    .savestate_start_ok         ( savestate_start_ok         ),
    .savestate_start_err        ( savestate_start_err        ),

    .savestate_load             ( savestate_load             ),
    .savestate_load_ack         ( savestate_load_ack         ),
    .savestate_load_busy        ( savestate_load_busy        ),
    .savestate_load_ok          ( savestate_load_ok          ),
    .savestate_load_err         ( savestate_load_err         ),

    .osnotify_inmenu            ( osnotify_inmenu            ),
    
    .target_dataslot_read       ( target_dataslot_read       ),
    .target_dataslot_write      ( target_dataslot_write      ),
    .target_dataslot_getfile    ( target_dataslot_getfile    ),
    .target_dataslot_openfile   ( target_dataslot_openfile   ),
    
    .target_dataslot_ack        ( target_dataslot_ack        ),
    .target_dataslot_done       ( target_dataslot_done       ),
    .target_dataslot_err        ( target_dataslot_err        ),

    .target_dataslot_id         ( target_dataslot_id         ),
    .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
    .target_dataslot_length     ( target_dataslot_length     ),

    .target_buffer_param_struct ( target_buffer_param_struct ),
    .target_buffer_resp_struct  ( target_buffer_resp_struct  ),
    
    .datatable_addr             ( datatable_addr             ),
    .datatable_wren             ( datatable_wren             ),
    .datatable_data             ( datatable_data             ),
    .datatable_q                ( datatable_q                )

);

wire clk_sys, clk_ram, clk_ram_90, clk_vid, clk_vid_90;

wire    pll_core_locked;
wire    pll_core_locked_s;
wire    reset_n_s;

synch_3 s01(pll_core_locked, pll_core_locked_s, clk_ram);
synch_3 s02(reset_n, reset_n_s, clk_sys);
synch_3 s03(external_reset, external_reset_s, clk_sys);

mf_pllbase mp1
(
    .refclk   ( clk_74a         ),
    .rst      ( 0               ),
    
    .outclk_0 ( clk_ram         ),
    .outclk_1 ( clk_sys         ),
    .outclk_2 ( clk_vid         ),
    .outclk_3 ( clk_vid_90      ),
    
    .locked   ( pll_core_locked )
);

wire CLK_VIDEO    = clk_ram;

wire external_reset = reset_delay > 0;
wire external_reset_s;

data_loader #(
  .ADDRESS_MASK_UPPER_4(4'h1),
  .OUTPUT_WORD_SIZE(1)
) data_loader (
  .clk_74a(clk_74a),
  .clk_memory(clk_sys),

  .bridge_wr(bridge_wr),
  .bridge_endian_little(bridge_endian_little),
  .bridge_addr(bridge_addr),
  .bridge_wr_data(bridge_wr_data),

  .write_en  (ioctl_wr),
  .write_addr(ioctl_addr),  // Unused
  .write_data(ioctl_dout)
);

//////// Start GB/GBC Stuff ////////

reg ioctl_download = 0;

always @(posedge clk_74a) begin
    if (dataslot_requestwrite) ioctl_download <= 1;
    else if (dataslot_allcomplete) ioctl_download <= 0;
end

wire [15:0] joy0_rumble;

wire [14:0] cart_addr;
wire [22:0] mbc_addr;
wire cart_a15;
wire cart_rd;
wire cart_wr;
wire cart_oe;
wire [7:0] cart_di, cart_do;
wire nCS; // WRAM or Cart RAM CS

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wait;

wire cart_download       = ioctl_download && (dataslot_requestwrite_id[5:0] == 6'h01 || dataslot_requestwrite_id[7:0] == 8'h80);
wire md_download         = ioctl_download && (dataslot_requestwrite_id[7:0] == 8'h81);
wire palette_download    = ioctl_download && (dataslot_requestwrite_id == 3 /*|| !filetype*/);
wire sgb_border_download = ioctl_download && (dataslot_requestwrite_id == 2);
wire cgb_boot_download   = ioctl_download && (dataslot_requestwrite_id == 4);
wire dmg_boot_download   = ioctl_download && (dataslot_requestwrite_id == 5);
wire sgb_boot_download   = ioctl_download && (dataslot_requestwrite_id == 6);
wire boot_download       = cgb_boot_download | dmg_boot_download | sgb_boot_download;


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
wire RTC_inuse;
wire rumbling;

assign joy0_rumble = {8'd0, ((rumbling & rumble_en) ? 8'd128 : 8'd0)};

reg ce_32k; // 32768Hz clock for RTC
reg [9:0] ce_32k_div;
always @(posedge clk_sys) begin
    ce_32k_div <= ce_32k_div + 1'b1;
    ce_32k <= !ce_32k_div;
end

cart_top cart
(
    .reset                      ( reset             ),

    .clk_sys                    ( clk_sys           ),
    .ce_cpu                     ( ce_cpu            ),
    .ce_cpu2x                   ( ce_cpu2x          ),
    .speed                      ( speed             ),
    .megaduck                   ( megaduck          ),
    .mapper_sel                 ( mapper_sel        ),

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
    .ioctl_wr                   ( ioctl_wr          ),
    .ioctl_addr                 ( ioctl_addr        ),
    .ioctl_dout                 ( ioctl_dout        ),
    .ioctl_wait                 ( ioctl_wait        ),

    .bk_wr                      ( 0                 ),
    .bk_rtc_wr                  ( 0                 ),
    .bk_addr                    ( 0                 ),
    .bk_data                    ( 0                 ),
    .bk_q                       (                   ),
    .img_size                   ( 0                 ),

    .rom_di                     ( rom_do            ),

    .joystick_analog_0          ( 0                 ),

    .ce_32k                     ( ce_32k            ),
    .RTC_time                   ( rtc_epoch_seconds ),
    .RTC_timestampOut           ( RTC_timestampOut  ),
    .RTC_savedtimeOut           ( RTC_savedtimeOut  ),
    .RTC_inuse                  ( RTC_inuse         ),

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
    
    .rumbling                   ( rumbling          )
);

reg [127:0] palette = 128'h828214517356305A5F1A3B4900000000;

always @(posedge clk_sys) begin
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

wire reset = (~reset_n_s | external_reset_s | cart_download | boot_download);
wire speed;
reg megaduck = 0;

reg isGBC = 0;
wire sys_auto     = (sys_type == 0);
wire sys_gbc      = (sys_type == 2);
wire sys_megaduck = (sys_type == 3);

always @(posedge clk_sys) if(reset) begin
    if (cart_download)
        megaduck <= sys_megaduck;
    if (md_download)
        megaduck <= sys_auto || sys_megaduck;

    if(~sys_auto) isGBC <= sys_gbc;
    else if(cart_download) begin
        if (!dataslot_requestwrite_id[5:0]) isGBC <= isGBC_game;
        else isGBC <= !dataslot_requestwrite_id[7:6];
    end
end

wire [15:0] GB_AUDIO_L;
wire [15:0] GB_AUDIO_R;

// the gameboy itself
gb gb
(
    .reset                  ( reset             ),
    
    .clk_sys                ( clk_sys           ),
    .ce                     ( ce_cpu            ),   // the whole gameboy runs on 4mhnz
    .ce_2x                  ( ce_cpu2x          ),   // ~8MHz in dualspeed mode (GBC)
    
    .isGBC                  ( isGBC             ),
    .real_cgb_boot          ( 1                 ),  
    .isSGB                  ( |sgb_en & ~isGBC  ),
    .megaduck               ( megaduck          ),

    .joy_p54                ( joy_p54           ),
    .joy_din                ( joy_do_sgb        ),

    // interface to the "external" game cartridge
    .ext_bus_addr           ( cart_addr         ),
    .ext_bus_a15            ( cart_a15          ),
    .cart_rd                ( cart_rd           ),
    .cart_wr                ( cart_wr           ),
    .cart_do                ( cart_do           ),
    .cart_di                ( cart_di           ),
    .cart_oe                ( cart_oe           ),

    .nCS                    ( nCS               ),

    .boot_gba_en            ( 0                 ),
    .fast_boot_en           ( 0                 ),

    .cgb_boot_download      ( cgb_boot_download ),
    .dmg_boot_download      ( dmg_boot_download ),
    .sgb_boot_download      ( sgb_boot_download ),
    .ioctl_wr               ( ioctl_wr          ),
    .ioctl_addr             ( ioctl_addr        ),
    .ioctl_dout             ( ioctl_dout        ),

    // audio
    .audio_l                ( GB_AUDIO_L        ),
    .audio_r                ( GB_AUDIO_R        ),
    
    // interface to the lcd
    .lcd_clkena             ( lcd_clkena        ),
    .lcd_data               ( lcd_data          ),
    .lcd_data_gb            ( lcd_data_gb       ),
    .lcd_mode               ( lcd_mode          ),
    .lcd_on                 ( lcd_on            ),
    .lcd_vsync              ( lcd_vsync         ),
    
    .speed                  ( speed             ),
    .DMA_on                 ( DMA_on            ),
    
    // serial port
    .sc_int_clock2          (                   ),
    .serial_clk_in          ( 0                 ),
    .serial_data_in         ( 0                 ),
    .serial_clk_out         (                   ),
    .serial_data_out        (                   ),
    
    // Palette download will disable cheats option (HPS doesn't distinguish downloads),
    // so clear the cheats and disable second option (chheats enable/disable)
    .gg_reset               ( 0                 ),
    .gg_en                  ( 0                 ),
    .gg_code                ( 0                 ),
    .gg_available           (                   ),
    
    // savestates
    .increaseSSHeaderCount  ( 0                 ),
    .cart_ram_size          ( 0                 ),
    .save_state             ( 0                 ),
    .load_state             ( 0                 ),
    .savestate_number       ( 0                 ),
    .sleep_savestate        ( sleep_savestate   ),
    //.sleep_savestate        (),

    .SaveStateExt_Din       (                   ),
    .SaveStateExt_Adr       (                   ),
    .SaveStateExt_wren      (                   ),
    .SaveStateExt_rst       (                   ),
    .SaveStateExt_Dout      ( 0                 ),
    .SaveStateExt_load      (                   ),
    
    .Savestate_CRAMAddr     (                   ),
    .Savestate_CRAMRWrEn    (                   ),
    .Savestate_CRAMWriteData(                   ),
    .Savestate_CRAMReadData ( 0                 ),
    
    .SAVE_out_Din           (                   ),            // data read from savestate
    .SAVE_out_Dout          ( 0                 ),           // data written to savestate
    .SAVE_out_Adr           (                   ),           // all addresses are DWORD addresses!
    .SAVE_out_rnw           (                   ),            // read = 1, write = 0
    .SAVE_out_ena           (                   ),            // one cycle high for each action
    .SAVE_out_be            (                   ),            
    .SAVE_out_done          ( 0                 ),            // should be one cycle high when write is done or read value is valid
    
    .rewind_on              ( rw_en             ),
    .rewind_active          ( rw_en & cont1_key[10] )
);

// Sound

wire [15:0] audio_l, audio_r;
reg  [15:0] audio_buffer_l = 0, audio_buffer_r = 0;

assign audio_l = (fast_forward && ~ff_snd_en) ? 16'd0 : GB_AUDIO_L;
assign audio_r = (fast_forward && ~ff_snd_en) ? 16'd0 : GB_AUDIO_R;

// Buffer audio to have better fitting on audio route
always @(posedge clk_sys) begin
    audio_buffer_l <= audio_l;
    audio_buffer_r <= audio_r;
end

audio_mixer #(
  .DW(16),
  .STEREO(0)
) audio_mixer (
  .clk_74b      (clk_74b),
  .clk_audio    (clk_sys),

  .vol_att      (0),
  .mix          (0),

  .is_signed    (0),
  .core_l       (audio_buffer_l),
  .core_r       (audio_buffer_r),

  .audio_mclk   (audio_mclk),
  .audio_lrck   (audio_lrck),
  .audio_dac    (audio_dac)
);

// the lcd to vga converter
wire ce_pix;
wire [8:0] h_cnt, v_cnt;
wire h_end;

lcd lcd
(
    // serial interface
    .clk_sys        ( clk_sys    ),
    .ce             ( ce_cpu     ),

    .lcd_clkena     ( sgb_lcd_clkena ),
    .data           ( sgb_lcd_data   ),
    .mode           ( sgb_lcd_mode   ),  // used to detect begin of new lines and frames
    .on             ( sgb_lcd_on     ),
    .lcd_vs         ( sgb_lcd_vsync  ),
    .shadow         ( 0     ),

    .isGBC          ( isGBC      ),

    .tint           ( |tint       ),
    .inv            ( 0  ),
    .double_buffer  ( 0 ),
    .frame_blend    ( 0 ),
    .originalcolors ( 0 ),
    .analog_wide    ( 0 ),

    // Palettes
    .pal1           (palette[127:104]),
    .pal2           (palette[103:80]),
    .pal3           (palette[79:56]),
    .pal4           (palette[55:32]),

    .sgb_border_pix ( sgb_border_pix),
    .sgb_pal_en     ( sgb_pal_en ),
    .sgb_en         ( sgb_border_en ),
    .sgb_freeze     ( sgb_lcd_freeze),

    .clk_vid        ( CLK_VIDEO  ),
    .hs             ( video_hs_gb   ),
    .vs             ( video_vs_gb   ),
    .hbl            ( h_blank    ),
    .vbl            ( v_blank    ),
    .r              ( video_rgb_gb[23:16] ),
    .g              ( video_rgb_gb[15:8]  ),
    .b              ( video_rgb_gb[7:0]   ),
    .ce_pix         ( ce_pix     ),
    .h_cnt          ( h_cnt      ),
    .v_cnt          ( v_cnt      ),
    .h_end          ( h_end      )
);

wire [1:0] joy_p54;
wire [3:0] joy_do_sgb;
wire [14:0] sgb_lcd_data;
wire [15:0] sgb_border_pix;
wire sgb_lcd_clkena, sgb_lcd_on, sgb_lcd_vsync, sgb_lcd_freeze;
wire [1:0] sgb_lcd_mode;
wire sgb_pal_en;
wire sgb_border_en = sgb_en[1];

sgb sgb (
    .reset              ( reset       ),
    .clk_sys            ( clk_sys     ),
    .ce                 ( ce_cpu      ),

    .clk_vid            ( CLK_VIDEO   ),
    .ce_pix             ( ce_pix      ),

    .joystick_0         ( cont1_key  ),
    .joystick_1         ( cont2_key  ),
    .joystick_2         ( cont3_key  ),
    .joystick_3         ( cont4_key  ),
    .joy_p54            ( joy_p54    ),
    .joy_do             ( joy_do_sgb ),

    .sgb_en             ( |sgb_en & isSGB_game & (~isGBC | sgc_gbc_en) ),
    .tint               ( tint[1]     ),
    .isGBC_game         ( isGBC & isGBC_game ),

    .lcd_on             ( lcd_on      ),
    .lcd_clkena         ( lcd_clkena  ),
    .lcd_data           ( lcd_data    ),
    .lcd_data_gb        ( lcd_data_gb ),
    .lcd_mode           ( lcd_mode    ),
    .lcd_vsync          ( lcd_vsync   ),

    .h_cnt              ( h_cnt      ),
    .v_cnt              ( v_cnt      ),
    .h_end              ( h_end      ),

    .border_download    (sgb_border_download),
    .ioctl_wr           (ioctl_wr),
    .ioctl_addr         (ioctl_addr),
    .ioctl_dout         (ioctl_dout),

    .sgb_border_pix     ( sgb_border_pix  ),
    .sgb_pal_en         ( sgb_pal_en      ),
    .sgb_lcd_data       ( sgb_lcd_data    ),
    .sgb_lcd_on         ( sgb_lcd_on      ),
    .sgb_lcd_freeze     ( sgb_lcd_freeze  ),
    .sgb_lcd_clkena     ( sgb_lcd_clkena  ),
    .sgb_lcd_mode       ( sgb_lcd_mode    ),
    .sgb_lcd_vsync      ( sgb_lcd_vsync   )
);

// Video
  wire h_blank;
  wire v_blank;
  wire video_hs_gb;
  wire video_vs_gb;
  wire [23:0] video_rgb_gb;

  reg video_de_reg;
  reg video_hs_reg;
  reg video_vs_reg;
  reg [23:0] video_rgb_reg;

  reg hs_prev;
  reg [2:0] hs_delay;
  reg vs_prev;
  reg de_prev;

  wire de = ~(h_blank || v_blank);

  always @(posedge clk_vid) begin
    video_hs_reg  <= 0;
    video_de_reg  <= 0;
    video_rgb_reg <= 24'h0;

    if (de) begin
      video_de_reg  <= 1;

      video_rgb_reg <= video_rgb_gb;
    end else if (de_prev && ~de) begin
      video_rgb_reg <= 24'h0;
    end

    if (hs_delay > 0) begin
      hs_delay <= hs_delay - 1;
    end

    if (hs_delay == 1) begin
      video_hs_reg <= 1;
    end

    if (~hs_prev && video_hs_gb) begin
      // HSync went high. Delay by 3 cycles to prevent overlapping with VSync
      hs_delay <= 7;
    end

    // Set VSync to be high for a single cycle on the rising edge of the VSync coming out of the core
    video_vs_reg <= ~vs_prev && video_vs_gb;
    hs_prev <= video_hs_gb;
    vs_prev <= video_vs_gb;
    de_prev <= de;
  end

  assign video_rgb_clock    = clk_vid;
  assign video_rgb_clock_90 = clk_vid_90;
  assign video_de           = video_de_reg;
  assign video_hs           = video_hs_reg;
  assign video_vs           = video_vs_reg;
  assign video_rgb          = video_rgb_reg;

//////////////////////////////// CE ////////////////////////////////////

wire ce_cpu, ce_cpu2x;
wire cart_act = cart_wr | cart_rd;

wire fastforward = cont1_key[8] && !ioctl_download;
wire ff_on;

wire sleep_savestate;

reg paused;
always_ff @(posedge clk_sys) begin
   paused <= sleep_savestate;
end

speedcontrol speedcontrol
(
    .clk_sys     (clk_sys),
    .pause       (paused),
    .speedup     (fast_forward),
    .cart_act    (cart_act),
    .DMA_on      (DMA_on),
    .ce          (ce_cpu),
    .ce_2x       (ce_cpu2x),
    .refresh     (sdram_refresh_force),
    .ff_on       (ff_on)
);

///////////////////////////// Fast Forward Latch /////////////////////////////////

reg fast_forward;
reg ff_latch;

always @(posedge clk_sys) begin : ffwd
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

        if (ff_count < 3200000 && ~ff_was_held) begin
            ff_was_held <= 1;
            ff_latch <= 1;
        end
    end

    fast_forward <= (fastforward | ff_latch);
end

endmodule