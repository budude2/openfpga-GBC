// Gameboy for the MiST
// (c) 2015 Till Harbaum

// The gameboy lcd runs from a shift register which is filled at 4194304 pixels/sec

module lcd
(
	input        clk_sys,
	input        ce,
	input        lcd_clkena,
	input        lcd_vs,
	input        shadow,

	input [14:0] data,

	input  [1:0] mode,
	input        isGBC,

	//palette
	input [23:0] pal1,
	input [23:0] pal2,
	input [23:0] pal3,
	input [23:0] pal4,

	input [15:0] sgb_border_pix,
	input        sgb_pal_en,
	input        sgb_en,
	input        sgb_freeze,

	input        tint,
	input        inv,
	input        originalcolors,
	input        analog_wide,

	input        on,

	// VGA output
	input            clk_vid, // 67.108864 MHz
	output reg       ce_pix,
	output reg	     hs,
	output reg 	     vs,
	output reg 	     hbl,
	output reg 	     vbl,
	output reg [8:0] h_cnt,
	output reg [8:0] v_cnt,
	output     [7:0] r,
	output     [7:0] g,
	output     [7:0] b,
	output           h_end
);

reg [14:0] vbuffer_inptr;
//reg vbuffer_in_bank;
reg lcd_off, lcd_freeze;
reg blank_de, blank_output;
reg [14:0] blank_data;
reg [16:0] lcd_off_cnt;

localparam BLANK_DELAY = 456*154;

wire pix_wr = ce & ( (lcd_clkena & ~lcd_freeze & ~sgb_freeze) | blank_de);
always @(posedge clk_sys) begin
	reg old_lcd_off, old_lcd_vs;
	reg [8:0] blank_hcnt,blank_vcnt;

	lcd_off <= !on || (mode == 2'd01);
	blank_de <= (!on && blank_output && blank_hcnt < 160 && blank_vcnt < 144);

	if (pix_wr) vbuffer_inptr <= vbuffer_inptr + 1'd1;

	old_lcd_off <= lcd_off;
	if(old_lcd_off ^ lcd_off) begin
		vbuffer_inptr <= 0;
		if (lcd_off) begin //LCD disabled or VBlank
			//if(~lcd_freeze & ~sgb_freeze) 
                //vbuffer_in_bank <= ~vbuffer_in_bank;
		end
	end

	// Delay blanking the screen for GBC
	if (on) lcd_off_cnt <= 0;
	else if (ce & ~&lcd_off_cnt) lcd_off_cnt <= lcd_off_cnt + 1'b1;

	if (~on) begin  // LCD disabled, start blank output
		lcd_freeze <= 1;
		if ( (~isGBC | (lcd_off_cnt > BLANK_DELAY) ) & ~blank_output) begin
			blank_output <= 1'b1;
			{blank_hcnt,blank_vcnt} <= 0;
		end
	end

	// Regenerate LCD timings for filling with blank color when LCD is off
	if (ce & ~on & blank_output) begin
		blank_data <= data;
		blank_hcnt <= blank_hcnt + 1'b1;
		if (blank_hcnt == 9'd455) begin
			blank_hcnt <= 0;
			blank_vcnt <= blank_vcnt + 1'b1;
			if (blank_vcnt == 9'd153) begin
				blank_vcnt <= 0;
				vbuffer_inptr <= 0;
				//vbuffer_in_bank <= ~vbuffer_in_bank;
			end
		end
	end

	// Output 1 blank/repeated frame until VSync after LCD is enabled
	old_lcd_vs <= lcd_vs;
	if (~old_lcd_vs & lcd_vs) begin
		if (lcd_freeze)
			lcd_freeze <= 0;
		if (blank_output)
			blank_output <= 0;
	end
end

reg [14:0] vbuffer[32768];
//always @(posedge clk_sys) if(pix_wr) vbuffer[{vbuffer_in_bank, vbuffer_inptr}] <= (on & blank_output) ? blank_data : data;
always @(posedge clk_sys) if(pix_wr) vbuffer[vbuffer_inptr] <= (on & blank_output) ? blank_data : data;

// Mode 00:  h-blank
// Mode 01:  v-blank
// Mode 10:  oam
// Mode 11:  oam and vram	

// Narrow
parameter H      = 9'd160;   // width of visible area
parameter HFP    = 9'd103;   // unused time before hsync
parameter HS     = 9'd32;    // width of hsync
parameter HBP    = 9'd130;   // unused time after hsync
parameter HTOTAL = H+HFP+HS+HBP;
// total = 425

// Wide
parameter HFP_W    = 9'd76;
parameter HS_W     = 9'd26;
parameter HBP_W    = 9'd92;
parameter HTOTAL_W = H+HFP_W+HS_W+HBP_W;
// total = 354

parameter H_BORDER = 9'd48;
parameter V_BORDER = 9'd40;
parameter H_START  = 9'd9+H_BORDER;

parameter V        = 144; // height of visible area
parameter VS_START = 37;  // start of vsync
parameter VSTART   = 105; // start of active video
parameter VTOTAL   = 264;

wire [8:0] h_total  = analog_wide ? HTOTAL_W : HTOTAL;
wire [8:0] hs_start = analog_wide ? (H_START+H+HFP_W)      : (H_START+H+HFP);
wire [8:0] hs_end   = analog_wide ? (H_START+H+HFP_W+HS_W) : (H_START+H+HFP+HS);
assign     h_end    = (h_cnt == h_total-1);

// (67108864 / 32 / 228 / 154) == (67108864 / 10 /  425.6 / 264) == 59.7275Hz
// We need 4256 cycles per line so 1 pixel clock cycle needs to be 6 cycles longer.
// Narrow: 424x10 + 1x16 cycles
// Wide:   352x12 + 2x16 cycles
reg [3:0] pix_div_cnt;
reg ce_pix_n;
always @(posedge clk_vid) begin
	pix_div_cnt <= pix_div_cnt + 1'd1;
	// Longer cycle at the last pixel(s)
	if ( (~analog_wide && ~h_end && pix_div_cnt == 4'd9) || (analog_wide && h_cnt < h_total-2 && pix_div_cnt == 4'd11) )
		pix_div_cnt <= 0;

	ce_pix <= !pix_div_cnt;
	ce_pix_n <= (pix_div_cnt == 4'd5);
end

reg [14:0] vbuffer_outptr;
//reg vbuffer_out_bank;
reg [1:0] shadow_buf[160];

reg hb, vb, gb_hb, gb_vb, wait_vbl;
always @(posedge clk_vid) begin
	reg [14:0] inptr,inptr1,inptr2;
	reg old_lcd_off;
	reg old_on;

	inptr2 <= vbuffer_inptr;
	inptr1 <= inptr2;
	if(inptr1 == inptr2) inptr <= inptr1;

	if (ce_pix_n) begin
		// generate positive hsync signal
		if(h_cnt == hs_end)
			hs <= 0;
		if(h_cnt == hs_start) begin
			hs <= 1;

			// generate positive vsync signal
			if(v_cnt == VS_START)   vs <= 1;
			if(v_cnt == VS_START+3) vs <= 0;
		end

		// Hblank
		if(h_cnt == H_START)        gb_hb <= 0;
		if(h_cnt == H_START+H)      gb_hb <= 1;

		if(h_cnt == H_START-H_BORDER)      hb <= 0;
		if(h_cnt == H_START+H_BORDER+H)    hb <= 1;

		// Vblank
		if(v_cnt == VSTART)    gb_vb <= 0;
		if(v_cnt == VSTART+V)  gb_vb <= 1;

		if(v_cnt == VSTART-V_BORDER)            vb <= 0;
		if(v_cnt == VSTART+V_BORDER+V-VTOTAL)   vb <= 1;
	end

	if(ce_pix) begin

		h_cnt <= h_cnt + 1'd1;
		if(h_end) begin
			h_cnt <= 0;
			if(~(vb & wait_vbl)) v_cnt <= v_cnt + 1'd1;
			if(v_cnt >= VTOTAL-1) v_cnt <= 0;

			if(v_cnt == VSTART-1) begin
				vbuffer_outptr 	<= 0;
				// Read from write buffer if it is far enough ahead
				//vbuffer_out_bank <= (inptr >= (160*60) || ~double_buffer) ? vbuffer_in_bank : ~vbuffer_in_bank;
			end
		end

		// visible area?
		if(~gb_hb & ~gb_vb) begin
			vbuffer_outptr <= vbuffer_outptr + 1'd1;
		end
	end

	old_lcd_off <= lcd_off;
	old_on <= on;
	
	// Lcd turned on. Wait in vblank for output reset.
	if (~old_on & on & ~vb) wait_vbl <= 1'b1; // lcd enabled

	if (old_lcd_off & ~lcd_off & vb) begin // lcd enabled or out of vblank
		wait_vbl <= 0;
		h_cnt <= 0;
		v_cnt <= 0;
		hs    <= 0;
		vs    <= 0;
	end
end

// -------------------------------------------------------------------------------
// ------------------------------- pixel generator -------------------------------
// -------------------------------------------------------------------------------
reg [14:0] pixel_reg;
reg [7:0] shptr = 0;
//always @(posedge clk_vid) pixel_reg <= vbuffer[{vbuffer_out_bank, vbuffer_outptr}];
always @(posedge clk_vid) pixel_reg <= vbuffer[vbuffer_outptr];

always @(posedge clk_vid) begin
	if(ce_pix) begin
		if (~gb_hb & ~gb_vb) begin
			shadow_buf[shptr] <= pixel;
		end
		shptr <= (shptr == 159) ? 8'd0 : shptr + 1'd1;
	end
	if (gb_hb)
		shptr <= 0;
	if (gb_vb)
		shadow_buf[shptr] <= 2'd0;
end

// Current pixel_reg latched at ce_pix_n so it is ready at ce_pix
reg [14:0] pixel_out;
always@(posedge clk_vid) begin
	if (ce_pix_n) pixel_out <= pixel_reg;
end

wire [1:0] pixel = (pixel_out[1:0] ^ {inv,inv}); //invert gb only

wire  [4:0] r5 = pixel_out[4:0];
wire  [4:0] g5 = pixel_out[9:5];
wire  [4:0] b5 = pixel_out[14:10];

wire [31:0] r10 = (r5 * 13) + (g5 * 2) +b5;
wire [31:0] g10 = (g5 * 3) + b5;
wire [31:0] b10 = (r5 * 3) + (g5 * 2) + (b5 * 11);

// greyscale
wire [7:0] grey = (pixel==0) ? 8'd252 : (pixel==1) ? 8'd168 : (pixel==2) ? 8'd96 : 8'd0;

// sgb_border_pix contains backdrop color when sgb_border_pix[15] is low.
wire sgb_border = sgb_border_pix[15] & sgb_en;

function [7:0] blend;
	input [7:0] a,b;
	reg [8:0] sum;
	begin
		sum = a + b;
		blend = sum[8:1];
	end
endfunction

reg [7:0] r_tmp, g_tmp, b_tmp;
always@(*) begin
	if (~sgb_pal_en & isGBC & !originalcolors) begin
		r_tmp = r10[8:1];
		g_tmp = {g10[6:0],1'b0};
		b_tmp = b10[8:1];
	end else if (sgb_pal_en | (isGBC & originalcolors)) begin
		r_tmp = {r5,r5[4:2]};
		g_tmp = {g5,g5[4:2]};
		b_tmp = {b5,b5[4:2]};
	end else if (tint) begin
		{r_tmp,g_tmp,b_tmp} = (pixel==0) ? pal1 : (pixel==1) ? pal2 : (pixel==2) ? pal3 : pal4;
	end else begin
		{r_tmp,g_tmp,b_tmp} = {3{grey}};
	end
end

reg [7:0] r_prev, g_prev, b_prev;
reg [7:0] r_cur, g_cur, b_cur;
reg [14:0] sgb_border_d;
reg hbl_l, vbl_l;
reg border_en;
reg [1:0] sc1, sc;
reg [7:0] rt, gt, bt;
reg shadow_end1, shadow_end2;
wire shadow_en = shadow && ~isGBC ;
assign r = shadow_end2 ? ((rt >> 1) + (rt >> 2) + (~sc[1] ? (rt >> 3) : 1'd0) + (~sc[0] ? (rt >> 4) : 1'd0)) : rt;
assign g = shadow_end2 ? ((gt >> 1) + (gt >> 2) + (~sc[1] ? (gt >> 3) : 1'd0) + (~sc[0] ? (gt >> 4) : 1'd0)) : gt;
assign b = shadow_end2 ? ((bt >> 1) + (bt >> 2) + (~sc[1] ? (bt >> 3) : 1'd0) + (~sc[0] ? (bt >> 4) : 1'd0)) : bt;
always@(posedge clk_vid) begin

	if (ce_pix) begin
		{r_cur, g_cur, b_cur} <= {r_tmp, g_tmp, b_tmp};
		shadow_end1 <= shadow_en && (|shadow_buf[shptr]) && (pixel == 0);
		sc1 <= shadow_buf[shptr];
		sc <= sc1;
		shadow_end2 <= (shadow_end1 && ~border_en);
	end

	if (ce_pix) begin
		// visible area?
		hbl_l <= sgb_en ? hb : gb_hb;
		vbl_l <= sgb_en ? vb : gb_vb;
		hbl <= hbl_l;
		vbl <= vbl_l;

		// Allow backdrop color in border area and the border to overlap game area.
		border_en <= ((gb_hb|gb_vb) & sgb_en) | sgb_border;
		sgb_border_d <= sgb_border_pix[14:0];

		if (border_en) begin
			rt <= {sgb_border_d[4:0],sgb_border_d[4:2]};
			gt <= {sgb_border_d[9:5],sgb_border_d[9:7]};
			bt <= {sgb_border_d[14:10],sgb_border_d[14:12]};
		end else begin
			{rt,gt,bt} <= {r_cur, g_cur, b_cur};
		end
	end

end

endmodule
