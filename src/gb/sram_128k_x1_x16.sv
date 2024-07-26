//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// SRAM Controller
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

module sram
    (
        // Clock and Reset
        input  wire        clk,       //! Input Clock
        input  wire        reset,     //! Reset
        output wire        sram_wipe_done,

        // Single Port Internal Bus Interface
        input  wire        we,        //! Write Enable
        input  wire        ub,
        input  wire        lb,
        input  wire [16:0] addr,      //! Address In
        input  wire [15:0] d,         //! Data In
        output  reg [15:0] q,         //! Data Out

        // SRAM External Interface
        output  reg [16:0] sram_addr, //! Address Out
        inout   reg [15:0] sram_dq,   //! Data In/Out
        output  reg        sram_oe_n, //! Output Enable
        output  reg        sram_we_n, //! Write Enable
        output  reg        sram_ub_n, //! Upper Byte Mask
        output  reg        sram_lb_n  //! Lower Byte Mask
    );

    typedef enum logic [1:0] {
        RESET_MEMORY,
        NORMAL_OPERATION
    } state_t;

    state_t state, next_state;
    reg [16:0] reset_counter;

    // State machine transitions
    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            state <= RESET_MEMORY;
            reset_counter <= 0;
        end
        else begin
            state <= next_state;
            if (state == RESET_MEMORY) begin
                reset_counter <= reset_counter + 1;
            end
        end
    end

    // State machine logic
    always_ff @(posedge clk) begin : sramFSM
        case (state)
            RESET_MEMORY: begin
                sram_wipe_done    <= 0;
                {sram_lb_n, sram_ub_n} <= 2'b00;     // Unmask Low/High Byte
                sram_addr <= reset_counter;          // Set Address
                sram_dq   <= 16'h0000;               // Write Zeros
                {sram_oe_n, sram_we_n} <= 2'b10;     // Output Disabled/Write Enabled

                if (reset_counter == 17'h1FFFF) begin
                    next_state <= NORMAL_OPERATION;
                end
                else begin
                    next_state <= RESET_MEMORY;
                end
            end
            NORMAL_OPERATION: begin
                sram_wipe_done    <= 1;
                sram_addr <= {17{1'bX}};             // Set Address as "Don't Care"
                sram_dq   <= {16{1'bZ}};             // Set Data Bus as High Impedance (Tristate)
                if(we) begin
                    {sram_lb_n, sram_ub_n} <= {~lb, ~ub};
                    {sram_oe_n, sram_we_n} <= 2'b10; // Output Disabled/Write Enabled
                    sram_addr <= addr;               // Set Address
                    sram_dq   <= d;                  // Write Data
                end
                else begin
                    {sram_lb_n, sram_ub_n} <= 2'b00; // Mask Low/High Byte 
                    {sram_oe_n, sram_we_n} <= 2'b01; // Write Disabled/Output Enabled
                    sram_addr <= addr;               // Set Address
                    q         <= sram_dq;            // Read Data
                end
                next_state <= NORMAL_OPERATION;
            end

            default: begin
                next_state <= RESET_MEMORY;
            end
        endcase
    end

endmodule
