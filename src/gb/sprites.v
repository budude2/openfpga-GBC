//
// sprites.v
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

module sprites (
	input clk,
	input ce,
	input ce_cpu,
	input size16,
	input isGBC,
	input sprite_en,

	input lcd_on,

	// pixel position input which the current pixel is generated for
	input [7:0] v_cnt,
	input [7:0] h_cnt,
	
	input sprite_fetch_done,
	output sprite_fetch,

	input oam_fetch,
	input oam_eval_reset,
	output oam_eval,

	output [10:0] sprite_addr,
	output reg [7:0] sprite_attr,
	output [3:0] sprite_index,

	output oam_eval_end,

	// oam memory interface
	input dma_active,
	input oam_wr,
	input [7:0] oam_addr_in,
	input [7:0] oam_di,
	output [7:0] oam_do,
   
   // savestates
   input [7:0] Savestate_OAMRAMAddr,     
   input       Savestate_OAMRAMRWrEn,    
   input [7:0] Savestate_OAMRAMWriteData,
   output[7:0] Savestate_OAMRAMReadData  
);

localparam SPRITES_PER_LINE = 10;

reg [7:0] oam_spr_addr;
wire [7:0] oam_fetch_addr;
reg [7:0] oam_q;

reg oam_eval_en;
assign oam_eval = lcd_on & ~oam_eval_end & oam_eval_en & ~oam_eval_reset;

wire [7:0] oam_addr = dma_active ? oam_addr_in :
						oam_eval ? oam_spr_addr :
						oam_fetch ? oam_fetch_addr :
						oam_addr_in;
                  
wire valid_oam_addr = (oam_addr[7:4] < 4'hA); // $FEA0 - $FEFF unused range
assign oam_do = dma_active ? 8'hFF : valid_oam_addr ? oam_q : 8'd0;


dpram #(8) oam_data (
	.clock_a   (clk      ),
	.address_a (oam_addr ),
	.wren_a    (ce_cpu && oam_wr && valid_oam_addr),
	.data_a    (oam_di   ),
	.q_a       (oam_q    ),
	
	.clock_b   (clk),
	.address_b (Savestate_OAMRAMAddr     ),
	.wren_b    (Savestate_OAMRAMRWrEn    ),
	.data_b    (Savestate_OAMRAMWriteData),
	.q_b       (Savestate_OAMRAMReadData )
);

reg [7:0] sprite_x[0:SPRITES_PER_LINE-1];
reg [3:0] sprite_y[0:SPRITES_PER_LINE-1];
reg [5:0] sprite_no[0:SPRITES_PER_LINE-1];

// OAM evaluation. Get the first 10 sprites on the current line.
reg [5:0] spr_index; // 40 sprites
reg [3:0] sprite_cnt;
reg sprite_cycle;

reg [7:0] spr_y;
wire [7:0] spr_height = size16 ? 8'd16 : 8'd8;
wire sprite_on_line = (v_cnt + 8'd16 >= spr_y) && (v_cnt + 8'd16 < spr_y + spr_height);

assign oam_eval_end = (spr_index == 6'd40);

wire [0:9] sprite_x_matches;

reg old_fetch_done;
integer spr_i = 0;
always @(posedge clk) begin
	if (ce) begin

		if (oam_eval_reset | ~lcd_on) begin
			sprite_cnt <= 0;
			spr_index <= ~lcd_on ? 6'd1 : 6'd0;
			sprite_cycle <= 0;
			oam_spr_addr <= 0;
			oam_eval_en <= oam_eval_reset ? 1'b1 : 1'b0; // OAM evaluation does not run on the first line after enabling the lcd
			for (spr_i=0; spr_i < SPRITES_PER_LINE; spr_i=spr_i+1) begin
				sprite_x[spr_i] <= 8'hFF;
				sprite_no[spr_i] <= 6'd0;
			end
		end else begin

			if (~oam_eval_end) begin
				if (sprite_cycle) spr_index <= spr_index + 1'b1;

				if (oam_eval_en && sprite_cnt < SPRITES_PER_LINE) begin
					if (~sprite_cycle) begin
						spr_y <= oam_do;
						oam_spr_addr <= {spr_index,2'b01};
					end else begin
						if (sprite_on_line) begin
							sprite_no[sprite_cnt] <= spr_index;
							sprite_x[sprite_cnt] <= oam_do;
							sprite_y[sprite_cnt] <= v_cnt[3:0] - spr_y[3:0];
							sprite_cnt <= sprite_cnt + 1'b1;
						end
						oam_spr_addr <= {spr_index+1'b1, 2'b00};
					end
				end

				sprite_cycle <= ~sprite_cycle;
			end

			// Set X-position to FF after fetching the sprite to prevent fetching it again.
			old_fetch_done <= sprite_fetch_done;
			if (~old_fetch_done & sprite_fetch_done) begin
				if (sprite_x_matches[0]) sprite_x[0] <= 8'hFF;
				else if (sprite_x_matches[1]) sprite_x[1] <= 8'hFF;
				else if (sprite_x_matches[2]) sprite_x[2] <= 8'hFF;
				else if (sprite_x_matches[3]) sprite_x[3] <= 8'hFF;
				else if (sprite_x_matches[4]) sprite_x[4] <= 8'hFF;
				else if (sprite_x_matches[5]) sprite_x[5] <= 8'hFF;
				else if (sprite_x_matches[6]) sprite_x[6] <= 8'hFF;
				else if (sprite_x_matches[7]) sprite_x[7] <= 8'hFF;
				else if (sprite_x_matches[8]) sprite_x[8] <= 8'hFF;
				else if (sprite_x_matches[9]) sprite_x[9] <= 8'hFF;
			end

		end
	end
end


// Sprite fetching
assign sprite_x_matches = {
		sprite_x[0] == h_cnt,
		sprite_x[1] == h_cnt,
		sprite_x[2] == h_cnt,
		sprite_x[3] == h_cnt,
		sprite_x[4] == h_cnt,
		sprite_x[5] == h_cnt,
		sprite_x[6] == h_cnt,
		sprite_x[7] == h_cnt,
		sprite_x[8] == h_cnt,
		sprite_x[9] == h_cnt
};

assign sprite_fetch = |sprite_x_matches & oam_fetch & (isGBC | sprite_en);

wire [3:0] active_sprite =
		sprite_x_matches[0] ? 4'd0 :
		sprite_x_matches[1] ? 4'd1 :
		sprite_x_matches[2] ? 4'd2 :
		sprite_x_matches[3] ? 4'd3 :
		sprite_x_matches[4] ? 4'd4 :
		sprite_x_matches[5] ? 4'd5 :
		sprite_x_matches[6] ? 4'd6 :
		sprite_x_matches[7] ? 4'd7 :
		sprite_x_matches[8] ? 4'd8 :
							  4'd9;
assign sprite_index = active_sprite;

wire [5:0] oam_fetch_index = sprite_no[active_sprite];

reg [3:0] row;
reg [7:0] tile_no;
reg oam_fetch_cycle;
assign oam_fetch_addr = {oam_fetch_index, 1'b1, oam_fetch_cycle};
assign sprite_addr = size16 ? {tile_no[7:1],row} : {tile_no,row[2:0]};

always @(posedge clk) begin
	if (ce) begin
		if (sprite_fetch) begin

			if (~oam_fetch_cycle) begin
				tile_no <= oam_do;
			end else begin
				sprite_attr <= oam_do;
				row <= oam_do[6] ? ~sprite_y[active_sprite] : sprite_y[active_sprite];
			end

			oam_fetch_cycle <= ~oam_fetch_cycle;
		end else begin
			oam_fetch_cycle <= 0;
		end
	end
end

endmodule