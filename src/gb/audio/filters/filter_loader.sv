//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Analogue Pocket Audio Filter Loader
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

module filter_loader
    (
        // Clocks and Reset
        input  logic        clk_sys,
        input  logic        afilter_wr,
        input  logic  [7:0] afilter_addr,
        input  logic  [7:0] afilter_din,
        // Audio From Core
        output logic [31:0] flt_rate,       // Sampling Frequency
        output logic [39:0] cx,             // Base gain
        output logic  [7:0] cx0, cx1, cx2,  // gain scale for X0, X1, X2
        output logic [23:0] cy0, cy1, cy2   // gain scale for Y0, Y1, Y2
    );

    always_comb begin
        flt_rate = r_flt_rate;
        cx       = r_cx;
        cx0      = r_cx0;
        cx1      = r_cx1;
        cx2      = r_cx2;
        cy0      = r_cy0;
        cy1      = r_cy1;
        cy2      = r_cy2;
    end

    reg [31:0] r_flt_rate = 7056000;       // Sampling Frequency
    reg [39:0] r_cx       = 4258969;       // Base gain
    reg  [7:0] r_cx0      = 3;             // gain scale for X0
    reg  [7:0] r_cx1      = 3;             // gain scale for X1
    reg  [7:0] r_cx2      = 1;             // gain scale for X2
    reg [23:0] r_cy0      = -24'd6216759;  // gain scale for Y0
    reg [23:0] r_cy1      =  24'd6143386;  // gain scale for Y1
    reg [23:0] r_cy2      = -24'd2023767;  // gain scale for Y2

    always_ff @(posedge clk_sys) begin
        if (afilter_wr) begin
            case(afilter_addr)
                //! Sampling Frequency
                8'h00: r_flt_rate[7:0]   <= afilter_din;
                8'h01: r_flt_rate[15:8]  <= afilter_din;
                8'h02: r_flt_rate[23:16] <= afilter_din;
                8'h03: r_flt_rate[31:24] <= afilter_din;
                //! Base gain
                8'h04: r_cx[7:0]         <= afilter_din;
                8'h05: r_cx[15:8]        <= afilter_din;
                8'h06: r_cx[23:16]       <= afilter_din;
                8'h07: r_cx[31:24]       <= afilter_din;
                8'h08: r_cx[39:32]       <= afilter_din;
                // 8'h09: _SKIP_
                // 8'h0a: _SKIP_
                // 8'h0b: _SKIP_
                //! gain scale for X0
                8'h0c: r_cx0             <= afilter_din;
                //! gain scale for X1
                8'h0d: r_cx1             <= afilter_din;
                //! gain scale for X2
                8'h0e: r_cx2             <= afilter_din;
                //! gain scale for Y0
                8'h0f: r_cy0[7:0]        <= afilter_din;
                8'h10: r_cy0[15:8]       <= afilter_din;
                8'h11: r_cy0[23:16]      <= afilter_din;
                // 8'h12: _SKIP_
                //! gain scale for Y1
                8'h13: r_cy1[7:0]        <= afilter_din;
                8'h14: r_cy1[15:8]       <= afilter_din;
                8'h15: r_cy1[23:16]      <= afilter_din;
                // 8'h16: _SKIP_
                //! gain scale for Y2
                8'h17: r_cy2[7:0]        <= afilter_din;
                8'h18: r_cy2[15:8]       <= afilter_din;
                8'h19: r_cy2[23:16]      <= afilter_din;
                // 8'h1a: _SKIP_
                // 8'h1b: _SKIP_
                default:;
            endcase
        end
    end

endmodule
