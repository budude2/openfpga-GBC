//------------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Audio Mix
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

module audio_mix
    (
        input  wire        clk,         // system clock
        input  wire        ce,          // clock enable signal

        input  wire  [4:0] att,         // attenuation value
        input  wire  [1:0] mix,         // mixing value

        input  wire [15:0] core_audio,  // audio input from core
        input  wire [15:0] pre_in,      // audio input from preamp

        output  reg [15:0] pre_out = 0, // preamp output
        output  reg [15:0] out = 0      // final mixed audio output
    );

    reg signed [16:0] a1, a2, a3;   // signed registers for audio processing

    always @(posedge clk) begin
        if (ce) begin
            a1      <= {core_audio[15],core_audio}; // extend core_audio to 17 bits and store in a1
            pre_out <= a1[16:1];                    // store the upper 16 bits of a1 in pre_out

            // select mixing options
            case(mix)
                0: begin a2 <= a1;                                                      end // mix core_audio
                1: begin a2 <= $signed(a1) - $signed(a1[16:3]) + $signed(pre_in[15:2]); end // mix core_audio, and pre_in with attenuation
                2: begin a2 <= $signed(a1) - $signed(a1[16:2]) + $signed(pre_in[15:1]); end // mix core_audio, and pre_in with greater attenuation
                3: begin a2 <= {a1[16],a1[16:1]} + {pre_in[15],pre_in};                 end // mix core_audio, and pre_in with clipping
            endcase

            // if the highest bit of att is set, set a3 to 0 (Mute) else shift a2 right by att and store in a3
            a3 <= (att[4]) ? 0 : a2 >>> att[3:0];

            // Clamping
            out <= ^a3[16:15] ? {a3[16],{15{a3[15]}}} : a3[15:0];  // clamp the upper 16 bits of a3 and store in out
        end
    end

endmodule
