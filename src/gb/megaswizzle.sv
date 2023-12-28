module megaduck_swizzle
(
	input megaduck,
	input [15:0] a_in,
	output [15:0] a_out,

	input [7:0] snd_in_di,
	output [7:0] snd_in_do,

	input [7:0] snd_out_di,
	output [7:0] snd_out_do
);

// Swizzle around MegaDuck register to match GB registers.

	always_comb begin
		a_out = a_in;
		snd_in_do = snd_in_di;
		snd_out_do = snd_out_di;
		if (megaduck) begin
			case (a_in)
				16'hFF10:  a_out = 16'hFF40; //  LCDC
				16'hFF11:  a_out = 16'hFF41; //  STAT
				16'hFF12:  a_out = 16'hFF42; //  SCY
				16'hFF13:  a_out = 16'hFF43; //  SCX
				16'hFF18:  a_out = 16'hFF44; //  LY
				16'hFF19:  a_out = 16'hFF45; //  LYC
				16'hFF1A:  a_out = 16'hFF46; //  DMA
				16'hFF1B:  a_out = 16'hFF47; //  BGP
				16'hFF14:  a_out = 16'hFF48; //  OBP0
				16'hFF15:  a_out = 16'hFF49; //  OBP1
				16'hFF16:  a_out = 16'hFF4A; //  WY
				16'hFF17:  a_out = 16'hFF4B; //  WX

				// Audio registers
				16'hFF20:  a_out = 16'hFF10; //  NR10
				16'hFF21:  a_out = 16'hFF12; //  NR12
				16'hFF22:  a_out = 16'hFF11; //  NR11
				16'hFF23:  a_out = 16'hFF13; //  NR13
				16'hFF24:  a_out = 16'hFF14; //  NR14
				16'hFF25:  a_out = 16'hFF16; //  NR21
				16'hFF27:  a_out = 16'hFF17; //  NR22
				16'hFF28:  a_out = 16'hFF18; //  NR23
				16'hFF29:  a_out = 16'hFF19; //  NR24
				16'hFF2A:  a_out = 16'hFF1A; //  NR30
				16'hFF2B:  a_out = 16'hFF1B; //  NR31
				16'hFF2C:  a_out = 16'hFF1C; //  NR32
				16'hFF2D:  a_out = 16'hFF1E; //  NR34
				16'hFF2E:  a_out = 16'hFF1D; //  NR33
				// The final 7 registers are after the audio ram
				16'hFF40:  a_out = 16'hFF20; //  NR41
				16'hFF41:  a_out = 16'hFF22; //  NR43
				16'hFF42:  a_out = 16'hFF21; //  NR42
				16'hFF43:  a_out = 16'hFF23; //  NR44
				16'hFF44:  a_out = 16'hFF24; //  NR50
				16'hFF45:  a_out = 16'hFF26; //  NR52
				16'hFF46:  a_out = 16'hFF25; //  NR51
				default: a_out = a_in;
			endcase

			// Megaduck has reversed nybbles for some registers
			case (a_in[7:0])
				// NR12, NR22, NR42, NR43
				8'h21, 8'h27, 8'h42, 8'h41: begin
					snd_in_do = {snd_in_di[3:0], snd_in_di[7:4]};
					snd_out_do = {snd_out_di[3:0], snd_out_di[7:4]};
				end

				// NR32 swizzled volume bits
				// https://github.com/bbbbbr/hUGEDriver/commit/b7abcb10dae7b7ac6296568878474b35baee2bae
				// GB: Bits:6..5 : 00 = mute, 01 = 100%, 10 = 50%, 11 = 25%
				// MD: Bits:6..5 : 00 = mute, 11 = 100%, 10 = 50%, 01 = 25%
				8'h2C: begin
					snd_in_do[6] = ^snd_in_di[6:5];
					snd_out_do[6] = ^snd_out_di[6:5];
				end

				default: ;
			endcase
		end
	end
endmodule