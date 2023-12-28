//------------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// DC blocker filter using a simplified IIR structure.
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
//
// It utilizes feedback to achieve filtering, operating on a delayed version of
// the input signal (x0), a delayed version of the output signal (y1), and the
// current input and output signals (x1 and y0, respectively).
// The filter coefficients are determined by the sample rate of the input signal.
//
//------------------------------------------------------------------------------

`default_nettype none

module dc_blocker
    (
        input  logic        clk,          // Input clock signal
        input  logic        ce,           // Control enable signal
        input  logic        mute,         // Mute output signal

        input  logic        sample_rate,  // Sample rate input signal
        input  logic [15:0] din,          // Input data signal
        output logic [15:0] dout          // Output data signal
    );

    // Pad the input signal with zeros
    wire [39:0] x  = {din[15], din, 23'd0};
    // Subtract previous input sample from current input sample
    wire [39:0] x0 = x - (sample_rate ? {{11{x[39]}}, x[39:11]} : {{10{x[39]}}, x[39:10]});
    // Subtract previous output sample from current output sample
    wire [39:0] y1 = y - (sample_rate ? {{10{y[39]}}, y[39:10]} : {{09{y[39]}}, y[39:09]});
    // Subtract difference between previous input and output sample from current input sample
    wire [39:0] y0 = x0 - x1 + y1;

    // Registers to store previous input and output samples
    reg  [39:0] x1, y;

    always @(posedge clk) begin
        if(ce) begin
            // Update the previous input sample
            x1 <= x0;
            // Update the previous output sample
            y  <= ^y0[39:38] ? {{2{y0[39]}},{38{y0[38]}}} : y0;
        end
    end

    // Output the filtered sample, or zero if the mute signal is high
    assign dout = mute ? 16'd0 : y[38:23];

endmodule
