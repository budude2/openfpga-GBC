-----------------------------------------------------------------
--------------- Bus Package --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pBus_savestates is

   constant BUS_buswidth : integer := 64;
   constant BUS_busadr   : integer := 10;
   
   type regmap_type is record
      Adr         : integer range 0 to (2**BUS_busadr)-1;
      upper       : integer range 0 to BUS_buswidth-1;
      lower       : integer range 0 to BUS_buswidth-1;
      size        : integer range 0 to (2**BUS_busadr)-1;
      default     : std_logic_vector(BUS_buswidth-1 downto 0);
   end record;
  
end package;

-----------------------------------------------------------------
--------------- Reg Interface, verbose for Verilog --------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  

library work;
use work.pBus_savestates.all;

entity eReg_SavestateV is
   generic
   (
      index     : integer := 0;
      Adr       : integer range 0 to (2**BUS_busadr)-1;
      upper     : integer range 0 to BUS_buswidth-1;
      lower     : integer range 0 to BUS_buswidth-1;
      def       : std_logic_vector(BUS_buswidth-1 downto 0)
   );
   port 
   (
      clk       : in    std_logic;
      BUS_Din   : in    std_logic_vector(BUS_buswidth-1 downto 0);
      BUS_Adr   : in    std_logic_vector(BUS_busadr-1 downto 0);
      BUS_wren  : in    std_logic;
      BUS_rst   : in    std_logic;
      BUS_Dout  : out   std_logic_vector(BUS_buswidth-1 downto 0) := (others => '0');
      Din       : in    std_logic_vector(upper downto lower);
      Dout      : out   std_logic_vector(upper downto lower)
   );
end entity;

architecture arch of eReg_SavestateV is

   signal Dout_buffer : std_logic_vector(upper downto lower) := def(upper downto lower);
    
   signal AdrI : std_logic_vector(BUS_Adr'left downto 0);
    
begin

   AdrI <= std_logic_vector(to_unsigned(Adr + index, BUS_Adr'length));

   process (clk)
   begin
      if rising_edge(clk) then
      
         if (BUS_rst = '1') then
         
            Dout_buffer <= def(upper downto lower);
         
         else
      
            if (BUS_Adr = AdrI and BUS_wren = '1') then
               for i in lower to upper loop
                  Dout_buffer(i) <= BUS_Din(i);  
               end loop;
            end if;
          
         end if;
         
      end if;
   end process;
   
   Dout <= Dout_buffer;
   
   goutputbit: for i in lower to upper generate
      BUS_Dout(i) <= Din(i) when BUS_Adr = AdrI else '0';
   end generate;
   
   glowzero_required: if lower > 0 generate
      glowzero: for i in 0 to lower - 1 generate
         BUS_Dout(i) <= '0';
      end generate;
   end generate;
   
   ghighzero_required: if upper < BUS_buswidth-1 generate
      ghighzero: for i in upper + 1 to BUS_buswidth-1 generate
         BUS_Dout(i) <= '0';
      end generate;
   end generate;
   
end architecture;

-----------------------------------------------------------------
--------------- Reg Interface, nonverbose -----------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  

library work;
use work.pBus_savestates.all;

entity eReg_Savestate is
   generic
   (
      Reg       : regmap_type;
      index     : integer := 0
   );
   port 
   (
      clk       : in    std_logic;
      BUS_Din   : in    std_logic_vector(BUS_buswidth-1 downto 0);
      BUS_Adr   : in    std_logic_vector(BUS_busadr-1 downto 0);
      BUS_wren  : in    std_logic;
      BUS_rst   : in    std_logic;
      BUS_Dout  : out   std_logic_vector(BUS_buswidth-1 downto 0) := (others => '0');
      Din       : in    std_logic_vector(Reg.upper downto Reg.lower);
      Dout      : out   std_logic_vector(Reg.upper downto Reg.lower)
   );
end entity;

architecture arch of eReg_Savestate is
    
begin

	iReg_SavestateV : entity work.eReg_SavestateV
   generic map
   (
		index => index,
		Adr   => Reg.Adr,  
		upper => Reg.upper,
		lower => Reg.lower,
		def   => Reg.default  
   )
   port map
   (
      clk       => clk,     
      BUS_Din   => BUS_Din, 
      BUS_Adr   => BUS_Adr, 
      BUS_wren  => BUS_wren,
      BUS_rst   => BUS_rst, 
      BUS_Dout  => BUS_Dout,
      Din       => Din,     
      Dout      => Dout    
   );
   
   
end architecture;




