-- ****
-- T80(b) core. In an effort to merge and maintain bug fixes ....
--
--
-- Ver 300 started tidyup
-- MikeJ March 2005
-- Latest version from www.fpgaarcade.com (original www.opencores.org)
--
-- ****
--
-- Z80 compatible microprocessor core, synchronous top level with clock enable
-- Different timing than the original z80
-- Inputs needs to be synchronous and outputs may glitch
--
-- Version : 0240
--
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-- The latest version of this file can be found at:
--      http://www.opencores.org/cvsweb.shtml/t80/
--
-- Limitations :
--
-- File history :
--
--      0235 : First release
--
--      0236 : Added T2Write generic
--
--      0237 : Fixed T2Write with wait state
--
--      0238 : Updated for T80 interface change
--
--      0240 : Updated for T80 interface change
--
--      0242 : Updated for T80 interface change
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.T80_Pack.all;

use work.pBus_savestates.all;
use work.pReg_savestates.all;

entity GBse is
	generic(
		T2Write : integer := 2;  -- 0 => WR_n active in T3, 1 => WR_n active in T2, Other => WR_n active in T2+T3
		IOWait : integer := 1   -- 0 => Single cycle I/O, 1 => Std I/O cycle
	);
	port(
		RESET_n           : in     std_logic;
		CLK_n             : in     std_logic;
		CLKEN             : in     std_logic;
		WAIT_n            : in     std_logic;
		INT_n             : in     std_logic;
		NMI_n             : in     std_logic;
		BUSRQ_n           : in     std_logic;
		M1_n              : out    std_logic;
		MREQ_n            : buffer std_logic;
		IORQ_n            : buffer std_logic;
		RD_n              : buffer std_logic;
		WR_n              : buffer std_logic;
		RFSH_n            : out    std_logic;
		HALT_n            : out    std_logic;
		BUSAK_n           : out    std_logic;
		STOP              : out    std_logic;
		A                 : out    std_logic_vector(15 downto 0);
		DI                : in     std_logic_vector(7 downto 0);
		DO                : out    std_logic_vector(7 downto 0);
		isGBC             : in     std_logic; -- Gameboy Color
		-- savestates              
		SaveStateBus_Din  : in     std_logic_vector(BUS_buswidth-1 downto 0);
		SaveStateBus_Adr  : in     std_logic_vector(BUS_busadr-1 downto 0);
		SaveStateBus_wren : in     std_logic;
		SaveStateBus_rst  : in     std_logic;
		SaveStateBus_Dout : out    std_logic_vector(BUS_buswidth-1 downto 0)
	);
end GBse;

architecture rtl of GBse is

	signal IntCycle_n   : std_logic;
	signal NoRead       : std_logic;
	signal Write        : std_logic;
	signal IORQ         : std_logic;
	signal DI_Reg       : std_logic_vector(7 downto 0);
	signal MCycle       : std_logic_vector(2 downto 0);
	signal TState       : std_logic_vector(2 downto 0);

	-- savestates
	type t_reg_wired_or is array(0 to 1) of std_logic_vector(63 downto 0);
	signal reg_wired_or : t_reg_wired_or;
	
	signal SS_GBSE      : std_logic_vector(REG_SAVESTATE_GBSE.upper downto REG_SAVESTATE_GBSE.lower);
	signal SS_GBSE_BACK : std_logic_vector(REG_SAVESTATE_GBSE.upper downto REG_SAVESTATE_GBSE.lower);

begin

	iREG_SAVESTATE_GBSE : entity work.eReg_Savestate generic map ( REG_SAVESTATE_GBSE ) port map (CLK_n, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, reg_wired_or(0), SS_GBSE_BACK, SS_GBSE);  
	
	SS_GBSE_BACK(0)           <= RD_n;
	SS_GBSE_BACK(1)           <= WR_n;
	SS_GBSE_BACK(2)           <= IORQ_n;
	SS_GBSE_BACK(3)           <= MREQ_n;
	SS_GBSE_BACK(11 downto 4) <= DI_Reg;
	
	process (reg_wired_or)
		variable wired_or : std_logic_vector(63 downto 0);
	begin
		wired_or := reg_wired_or(0);
		for i in 1 to (reg_wired_or'length - 1) loop
			wired_or := wired_or or reg_wired_or(i);
		end loop;
		SaveStateBus_Dout <= wired_or;
	end process;

	u0 : T80
		generic map
	(
			Mode      => 3,
			IOWait    => IOWait,
			Flag_S    => 0,
			Flag_P    => 0,
			Flag_X    => 0,
			Flag_Y    => 0,
			Flag_C    => 4,
			Flag_H    => 5,
			Flag_N    => 6,
			Flag_Z    => 7
		)
		port map(
			CEN        => CLKEN,
			M1_n       => M1_n,
			IORQ       => IORQ,
			NoRead     => NoRead,
			Write      => Write,
			RFSH_n     => RFSH_n,
			HALT_n     => HALT_n,
			Stop       => STOP,
			WAIT_n     => Wait_n,
			INT_n      => INT_n,
			NMI_n      => NMI_n,
			RESET_n    => RESET_n,
			BUSRQ_n    => BUSRQ_n,
			BUSAK_n    => BUSAK_n,
			CLK_n      => CLK_n,
			A          => A,
			DInst      => DI,
			DI         => DI_Reg,
			DO         => DO,
			MC         => MCycle,
			TS         => TState,
			IntCycle_n => IntCycle_n,
			isGBC      => isGBC,
			-- savestates
			SaveStateBus_Din  => SaveStateBus_Din, 
			SaveStateBus_Adr  => SaveStateBus_Adr, 
			SaveStateBus_wren => SaveStateBus_wren,
			SaveStateBus_rst  => SaveStateBus_rst, 
			SaveStateBus_Dout => reg_wired_or(1)
		);

	process (CLK_n)
	begin
		if CLK_n'event and CLK_n = '1' then
			if RESET_n = '0' then
				RD_n   <=  SS_GBSE(0);           -- '1';
				WR_n   <=  SS_GBSE(1);           -- '1';
				IORQ_n <=  SS_GBSE(2);           -- '1';
				MREQ_n <=  SS_GBSE(3);           -- '1';
				DI_Reg <=  SS_GBSE(11 downto 4); -- "00000000";
			elsif CLKEN = '1' then
				RD_n <= '1';
				WR_n <= '1';
				IORQ_n <= '1';
				MREQ_n <= '1';
				if MCycle = "001" then
					if TState = "001" or TState = "010" then
						RD_n <= not IntCycle_n;
						MREQ_n <= not IntCycle_n;
					end if;
					if TState = "011" then
						MREQ_n <= '0';
					end if;
				elsif MCycle = "011" and IntCycle_n = '0' then
					if TState = "010" then
						IORQ_n <= '0'; -- Acknowledge IRQ
					end if;
				else
					if (TState = "001" or TState = "010") and (NoRead = '0' and Write = '0') then
						RD_n <= '0';
						IORQ_n <= not IORQ;
						MREQ_n <= IORQ;
					end if;
					if T2Write = 0 then
						if TState = "010" and Write = '1' then
							WR_n <= '0';
							IORQ_n <= not IORQ;
							MREQ_n <= IORQ;
						end if;
					elsif T2Write = 1 then
						if (TState = "001" or (TState = "010" and Wait_n = '0')) and Write = '1' then
							WR_n <= '0';
							IORQ_n <= not IORQ;
							MREQ_n <= IORQ;
						end if;
					else
						if (TState = "001" or TState = "010") and Write = '1' then
							WR_n <= '0';
							IORQ_n <= not IORQ;
							MREQ_n <= IORQ;
						end if;
					end if;
				end if;
				if TState = "011" and Wait_n = '1' then
					DI_Reg <= DI;
				end if;
			end if;
		end if;
	end process;

end;
