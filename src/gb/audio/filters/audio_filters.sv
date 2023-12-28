//------------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Audio Filters
//
// Copyright (c) 2023, Marcus Andrade <marcus@opengateware.org>
// Copyright (c) 2020, Alexey Melnikov <pour.garbage@gmail.com>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//
//------------------------------------------------------------------------------

`default_nettype none

module audio_filters
    #(
         parameter CLK_RATE = 12288000
     ) (
         input  wire        clk,
         input  wire        reset,

         input  wire [31:0] flt_rate,
         input  wire [39:0] cx,
         input  wire  [7:0] cx0,
         input  wire  [7:0] cx1,
         input  wire  [7:0] cx2,
         input  wire [23:0] cy0,
         input  wire [23:0] cy1,
         input  wire [23:0] cy2,
         input  wire  [4:0] att,

         input  wire        is_signed,
         input  wire  [1:0] mix,

         input  wire [15:0] core_l,
         input  wire [15:0] core_r,

         // Audio Output
         output wire [15:0] audio_l,
         output wire [15:0] audio_r
     );

    reg sample_rate = 0; //0 - 48KHz, 1 - 96KHz

    reg sample_ce;
    always @(posedge clk) begin
        reg [8:0] div = 0;
        reg [1:0] add = 0;

        div <= div + add;
        if(!div) begin
            div <= 2'd1 << sample_rate;
            add <= 2'd1 << sample_rate;
        end

        sample_ce <= !div;
    end

    reg flt_ce;
    always @(posedge clk) begin
        reg [31:0] cnt = 0;

        flt_ce = 0;
        cnt = cnt + {flt_rate[30:0],1'b0};
        if(cnt >= CLK_RATE) begin
            cnt = cnt - CLK_RATE;
            flt_ce = 1;
        end
    end

    reg [15:0] cl,cr;
    always @(posedge clk) begin
        reg [15:0] cl1, cl2;
        reg [15:0] cr1, cr2;

        cl1 <= core_l;
        cl2 <= cl1;
        if(cl2 == cl1)
            cl <= cl2;

        cr1 <= core_r;
        cr2 <= cr1;
        if(cr2 == cr1)
            cr <= cr2;
    end

    reg a_en1 = 0, a_en2 = 0;
    always @(posedge clk, posedge reset) begin
        reg  [1:0] dly1;
        reg [14:0] dly2;

        if(reset) begin
            dly1  <= 0;
            dly2  <= 0;
            a_en1 <= 0;
            a_en2 <= 0;
        end
        else begin
            if(flt_ce) begin
                if(~&dly1)
                    dly1 <= dly1 + 1'd1;
                else
                    a_en1 <= 1;
            end

            if(sample_ce) begin
                if(!dly2[13+sample_rate])
                    dly2 <= dly2 + 1'd1;
                else
                    a_en2 <= 1;
            end
        end
    end

    wire [15:0] acl, acr;
    iir_filter #(.use_params(0)) iir_filter
               (
                   .clk       ( clk            ),
                   .reset     ( reset          ),

                   .ce        ( flt_ce & a_en1 ),
                   .sample_ce ( sample_ce      ),

                   .cx        ( cx             ),
                   .cx0       ( cx0            ),
                   .cx1       ( cx1            ),
                   .cx2       ( cx2            ),
                   .cy0       ( cy0            ),
                   .cy1       ( cy1            ),
                   .cy2       ( cy2            ),

                   .input_l   ( {~is_signed ^ cl[15], cl[14:0]} ),
                   .input_r   ( {~is_signed ^ cr[15], cr[14:0]} ),
                   .output_l  ( acl ),
                   .output_r  ( acr )
               );

    wire [15:0] adl;
    dc_blocker dcb_l
               (
                   .clk         ( clk         ),
                   .ce          ( sample_ce   ),
                   .sample_rate ( sample_rate ),
                   .mute        ( ~a_en2      ),
                   .din         ( acl         ),
                   .dout        ( adl         )
               );

    wire [15:0] adr;
    dc_blocker dcb_r
               (
                   .clk         ( clk         ),
                   .ce          ( sample_ce   ),
                   .sample_rate ( sample_rate ),
                   .mute        ( ~a_en2      ),
                   .din         ( acr         ),
                   .dout        ( adr         )
               );

    wire [15:0] audio_l_pre;
    audio_mix audmix_l
              (
                  .clk         ( clk         ),
                  .ce          ( sample_ce   ),
                  .att         ( att         ),
                  .mix         ( mix         ),

                  .core_audio  ( adl         ),
                  .pre_in      ( audio_r_pre ),

                  .pre_out     ( audio_l_pre ),
                  .out         ( audio_l     )
              );

    wire [15:0] audio_r_pre;
    audio_mix audmix_r
              (
                  .clk         ( clk         ),
                  .ce          ( sample_ce   ),
                  .att         ( att         ),
                  .mix         ( mix         ),

                  .core_audio  ( adr         ),
                  .pre_in      ( audio_l_pre ),

                  .pre_out     ( audio_r_pre ),
                  .out         ( audio_r     )
              );

endmodule
