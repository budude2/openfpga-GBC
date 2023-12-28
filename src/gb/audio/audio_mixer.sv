//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Analogue Pocket Audio Mixer
//
// Copyright (c) 2023, Marcus Andrade <marcus@opengateware.org>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//------------------------------------------------------------------------------

`default_nettype none

module audio_mixer #(
    parameter DW     = 16,  //! Audio Data Width
    // parameter MUTE_PAUSE = 1,   //! Mute on Pause
    parameter STEREO = 1    //! Stereo Audio
) (
    // Clocks and Reset
    input  logic          clk_74b,     //! Clock 74.25Mhz
    input  logic          clk_audio,
    input  logic          reset,       //! Reset
    // Controls
    // input  logic [   3:0] afilter_sw,  //! Predefined Audio Filter Switch
    input  logic [   3:0] vol_att,     //! Volume ([0] Max | [7] Min)
    input  logic [   1:0] mix,         //! [0] No Mix | [1] 25% | [2] 50% | [3] 100% (mono)
    // input  logic          pause_core,  //! Mute Audio
    // Audio From Core
    input  logic          is_signed,   //! Signed Audio
    input  logic [DW-1:0] core_l,      //! Left  Channel Audio from Core
    input  logic [DW-1:0] core_r,      //! Right Channel Audio from Core
    // Pocket I2S
    output logic          audio_mclk,  //! Serial Master Clock
    output logic          audio_lrck,  //! Left/Right clock
    output logic          audio_dac    //! Serialized data
);

  //! ------------------------------------------------------------------------
  //! Audio Clocks
  //! MCLK: 12.288MHz (256*Fs, where Fs = 48000)
  //! SCLK:  3.072mhz (MCLK/4)
  //! ------------------------------------------------------------------------
  wire audio_sclk;

  mf_audio_pll audio_pll (
      .refclk  (clk_74b),
      .rst     (0),
      .outclk_0(audio_mclk),
      .outclk_1(audio_sclk)
  );

  //! ------------------------------------------------------------------------
  //! Pad core_l/core_r with zeros to maintain a consistent size of 16 bits
  //! ------------------------------------------------------------------------
  logic [15:0] core_al, core_ar;

  always_comb begin
    core_al = DW == 16 ? core_l : {core_l, {16 - DW{1'b0}}};
    core_ar = STEREO ? DW == 16 ? core_r : {core_r, {16 - DW{1'b0}}} : core_al;
  end

  //! ------------------------------------------------------------------------
  //! Low Pass Filter
  //! ------------------------------------------------------------------------
  reg [31:0] aflt_rate = 32'd7056000;  // Sampling Frequency
  reg [39:0] acx = 40'd4258969;  // Base gain
  reg [ 7:0] acx0 = 8'd3;  // gain scale for X0
  reg [ 7:0] acx1 = 8'd3;  // gain scale for X1
  reg [ 7:0] acx2 = 8'd1;  // gain scale for X2
  reg [23:0] acy0 = -24'd6216759;  // gain scale for Y0
  reg [23:0] acy1 = 24'd6143386;  // gain scale for Y1
  reg [23:0] acy2 = -24'd2023767;  // gain scale for Y2

  // logic [31:0] aflt_rate;
  // logic [39:0] acx;
  // logic  [7:0] acx0, acx1, acx2;
  // logic [23:0] acy0, acy1, acy2;

  // arcade_filters arcade_filters
  //                (
  //                    .clk        ( audio_mclk ),
  //                    .afilter_sw ( afilter_sw ),
  //                    .aflt_rate  ( aflt_rate  ),
  //                    .acx        ( acx        ),
  //                    .acx0       ( acx0       ),
  //                    .acx1       ( acx1       ),
  //                    .acx2       ( acx2       ),
  //                    .acy0       ( acy0       ),
  //                    .acy1       ( acy1       ),
  //                    .acy2       ( acy2       )
  //                );

  //! ------------------------------------------------------------------------
  //! Synchronization
  //! ------------------------------------------------------------------------

  logic [15:0] core_al_s, core_ar_s;

  sync_fifo #(
      .WIDTH(32)
  ) sync_fifo (
      .clk_write(clk_audio),
      .clk_read (audio_mclk),

      .write_en(write_en),
      .data({core_al, core_ar}),
      .data_s({core_al_s, core_ar_s})
  );

  reg write_en = 0;
  reg [15:0] prev_left;
  reg [15:0] prev_right;

  // Mark write when necessary
  always @(posedge clk_audio) begin
    prev_left  <= core_al;
    prev_right <= core_ar;

    write_en   <= 0;

    if (core_al != prev_left || core_ar != prev_right) begin
      write_en <= 1;
    end
  end

  //! ------------------------------------------------------------------------
  //! Audio Filters
  //! ------------------------------------------------------------------------
  logic [15:0] audio_l, audio_r;
  //   logic mute_audio = MUTE_PAUSE ? pause_core : 1'b0;

  audio_filters audio_filters (
      .clk      (audio_mclk),
      .reset    (reset),
      // Controls
      .att      ({1'b0, vol_att}),
      .mix      (mix),
      // Audio Filter
      .flt_rate (aflt_rate),
      .cx       (acx),
      .cx0      (acx0),
      .cx1      (acx1),
      .cx2      (acx2),
      .cy0      (acy0),
      .cy1      (acy1),
      .cy2      (acy2),
      // Audio from Core
      .is_signed(is_signed),
      .core_l   (core_al_s),
      .core_r   (core_ar_s),
      // Filtered Audio Output
      .audio_l  (audio_l),
      .audio_r  (audio_r)
  );

  //! ------------------------------------------------------------------------
  //! Pocket I2S Output
  //! ------------------------------------------------------------------------

  sound_i2s sound_i2s (
      .audio_sclk(audio_sclk),

      .audio_l(audio_l),
      .audio_r(audio_r),

      .audio_lrck(audio_lrck),
      .audio_dac (audio_dac)
  );

endmodule
