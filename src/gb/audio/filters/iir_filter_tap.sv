//------------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Infinite Impulse Response (IIR) filter tap.
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
// The iir_filter_tap module implements an infinite impulse response (IIR) filter
// with one tap. It takes in input data x, previous output data y, and an input z
// and calculates the output tap using a set of coefficients cx and cy. The
// coefficients are used to multiply the input data and previous output data,
// and the resulting values are then added together to produce the output tap.
// The module stores intermediate values in a logic RAM, and updates the values
// on each clock cycle based on the control signals ce and ch. The module uses
// a Verilog function to perform the multiplication of the input data with the
// coefficients.
//
//------------------------------------------------------------------------------

`default_nettype none

module iir_filter_tap
    (
        input  wire        clk,    // clock signal
        input  wire        reset,  // reset signal

        input  wire        ce,     // control signal
        input  wire        ch,     // control signal

        input  wire  [7:0] cx,    // coefficient value
        input  wire [23:0] cy,    // coefficient value

        input  wire [39:0] x,     // input data
        input  wire [39:0] y,     // previous output data
        input  wire [39:0] z,     // input data
        output wire [39:0] tap    // output data
    );

    // multiply previous output y with coefficient cy
    wire signed [60:0] y_mul = $signed(y[36:0]) * $signed(cy);

    // multiply input x with coefficient cx
    function [39:0] x_mul;
        input [39:0] x;
        begin
            x_mul = 0;
            if(cx[0]) x_mul =  x_mul + {{4{x[39]}}, x[39:4]}; // multiply x[39:36] with cx[0]
            if(cx[1]) x_mul =  x_mul + {{3{x[39]}}, x[39:3]}; // multiply x[39:35] with cx[1]
            if(cx[2]) x_mul =  x_mul + {{2{x[39]}}, x[39:2]}; // multiply x[39:34] with cx[2]
            if(cx[7]) x_mul = ~x_mul;                         // negate result if cx[7] is set
        end
    endfunction

    // use logic RAM to store intermediate values
    (* ramstyle = "logic" *) reg [39:0] intreg[2];
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            {intreg[0],intreg[1]} <= 80'd0;
        end
        else if(ce) begin
            // update intreg[ch] with new value
            intreg[ch] <= x_mul(x) - y_mul[60:21] + z;
            // multiply input x with cx, subtract a portion of previous output y (specified by cy),
            // add input z, and store the result in intreg[ch]
        end
    end

    // assign output tap to value in intreg corresponding to ch signal
    assign tap = intreg[ch];

endmodule
