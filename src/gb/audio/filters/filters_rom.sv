//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Analogue Pocket Audio Filters ROM
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

module filters_rom
    (
        // Clock
        input  logic        clk,
        // Filter Switch
        input  logic  [3:0] afilter_sw,
        // Filter Config
        output logic [31:0] aflt_rate,        // Sampling Frequency
        output logic [39:0] acx,              // Base gain
        output logic  [7:0] acx0, acx1, acx2, // gain scale for X0, X1, X2
        output logic [23:0] acy0, acy1, acy2  // gain scale for Y0, Y1, Y2
    );

    (* ramstyle = "no_rw_check" *) reg [31:0] flt_rate[9];
    (* ramstyle = "no_rw_check" *) reg [39:0] cx[9];
    (* ramstyle = "no_rw_check" *) reg  [7:0] cx0[9];
    (* ramstyle = "no_rw_check" *) reg  [7:0] cx1[9];
    (* ramstyle = "no_rw_check" *) reg  [7:0] cx2[9];
    (* ramstyle = "no_rw_check" *) reg [23:0] cy0[9];
    (* ramstyle = "no_rw_check" *) reg [23:0] cy1[9];
    (* ramstyle = "no_rw_check" *) reg [23:0] cy2[9];

    always @(posedge clk) begin
        aflt_rate <= flt_rate[afilter_sw];
        acx       <= cx[afilter_sw];
        acx0      <= cx0[afilter_sw];
        acx1      <= cx1[afilter_sw];
        acx2      <= cx2[afilter_sw];
        acy0      <= cy0[afilter_sw];
        acy1      <= cy1[afilter_sw];
        acy2      <= cy2[afilter_sw];
    end
    //! Assign Outputs ---------------------------------------------------------

    //! Arcade Filters ---------------------------------------------------------
    initial begin
        // Default
        flt_rate[0] = 7056000;
        cx[0]       = 4258969;
        cx0[0]      = 3;
        cx1[0]      = 3;
        cx2[0]      = 1;
        cy0[0]      = -24'd6216759;
        cy1[0]      =  24'd6143386;
        cy2[0]      = -24'd2023767;

        // Arcade LPF 2khz 1st
        flt_rate[1] = 32'd7056000;
        cx[1]       = 40'd425898;
        cx0[1]      = 8'd3;
        cx1[1]      = 8'd3;
        cx2[1]      = 8'd1;
        cy0[1]      = -24'd6234907;
        cy1[1]      =  24'd6179109;
        cy2[1]      = -24'd2041353;

        // Arcade LPF 2khz 2nd
        flt_rate[2] = 32'd7056000;
        cx[2]       = 40'd2420697;
        cx0[2]      = 8'd2;
        cx1[2]      = 8'd1;
        cx2[2]      = 8'd0;
        cy0[2]      = -24'd4189022;
        cy1[2]      =  24'd2091876;
        cy2[2]      = 24'd0;

        // Arcade LPF 4khz 1st
        flt_rate[3] = 32'd7056000;
        cx[3]       = 40'd851040;
        cx0[3]      = 8'd3;
        cx1[3]      = 8'd3;
        cx2[3]      = 8'd1;
        cy0[3]      = -24'd6231182;
        cy1[3]      =  24'd6171753;
        cy2[3]      = -24'd2037720;

        // Arcade LPF 4khz 2nd
        flt_rate[4] = 32'd7056000;
        cx[4]       = 40'd9670619;
        cx0[4]      = 8'd2;
        cx1[4]      = 8'd1;
        cx2[4]      = 8'd0;
        cy0[4]      = -24'd4183740;
        cy1[4]      =  24'd2086614;
        cy2[4]      = 24'd0;

        // Arcade LPF 6khz 1st
        flt_rate[5] = 32'd7056000;
        cx[5]       = 40'd1275428;
        cx0[5]      = 8'd3;
        cx1[5]      = 8'd3;
        cx2[5]      = 8'd1;
        cy0[5]      = -24'd6227464;
        cy1[5]      =  24'd6164410;
        cy2[5]      = -24'd2034094;

        // Arcade LPF 6khz 2nd
        flt_rate[6] = 32'd7056000;
        cx[6]       = 40'd21731566;
        cx0[6]      = 8'd2;
        cx1[6]      = 8'd1;
        cx2[6]      = 8'd0;
        cy0[6]      = -24'd4178458;
        cy1[6]      =  24'd2081365;
        cy2[6]      = 24'd0;

        // Arcade LPF 8khz 1st
        flt_rate[7] = 32'd7056000;
        cx[7]       = 40'd1699064;
        cx0[7]      = 8'd3;
        cx1[7]      = 8'd3;
        cx2[7]      = 8'd1;
        cy0[7]      = -24'd6223752;
        cy1[7]      =  24'd6157080;
        cy2[7]      = -24'd2030475;

        // Arcade LPF 8khz 2nd
        flt_rate[8] = 32'd7056000;
        cx[8]       = 40'd38585417;
        cx0[8]      = 8'd2;
        cx1[8]      = 8'd1;
        cx2[8]      = 8'd0;
        cy0[8]      = -24'd4173176;
        cy1[8]      =  24'd2076130;
        cy2[8]      = 24'd0;

    end

    // [  9 ] LPF 10khz 1st + Aa
    // [ 10 ] LPF 12khz 1st + Aa
    // [ 11 ] LPF 14khz 1st + Aa
    // [ 12 ] LPF 16khz 1st + Aa
    // [ 13 ] LPF 16khz 3rd Ch 1db
    // [ 14 ] LPF 18khz 3rd Ch 1db
    // [ 15 ] LPF 20khz 2nd Bw
    // [ 16 ] LPF 20khz 3rd Bw
    // [ 17 ] LPF 20khz 3rd Ch 1db

    // [ 18 ] SNES Gpm-02 LPF

endmodule
