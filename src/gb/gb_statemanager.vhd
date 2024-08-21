library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity gb_statemanager is
   generic
   (
      Softmap_SaveState_ADDR   : integer -- count:  262144    -- 256 Kbyte Data for Savestate
   );
   port 
   (
      clk                 : in    std_logic; 
      reset               : in    std_logic;
      
      save                : in    std_logic;  
      load                : in    std_logic;
      
      vsync               : in    std_logic;  
      
      request_savestate   : out   std_logic := '0';
      request_loadstate   : out   std_logic := '0';
      request_address     : out   integer;
      request_busy        : in    std_logic
   );
end entity;

architecture arch of gb_statemanager is

   constant SAVESTATESIZE : integer := 16#10000#; -- 65536 Dwords = 256kbyte

   signal save_1         : std_logic := '0';
   signal load_1         : std_logic := '0';
   signal save_buffer    : std_logic := '0';
   signal load_buffer    : std_logic := '0';
   
   signal vsync_counter  : integer range 0 to 2 := 0;
   
   signal vsync_1 : std_logic;

begin 
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         request_savestate <= '0';
         request_loadstate <= '0';
 
         vsync_1 <= vsync;
      
         save_1 <= save; 
         if (save = '1' and save_1 = '0') then
            save_buffer <= '1';
         end if;
         
         load_1 <= load;
         if (load = '1' and load_1 = '0') then
            load_buffer <= '1';
         end if;
         
         if (vsync_counter < 2 and vsync = '1' and vsync_1 = '0') then
            vsync_counter <= vsync_counter + 1;
         end if;
         
         if (reset = '0' and request_busy = '0') then
            if (save_buffer = '1') then
               request_address   <= Softmap_SaveState_ADDR;
               request_savestate <= '1';
               save_buffer       <= '0';
            elsif (load_buffer = '1') then
               request_address   <= Softmap_SaveState_ADDR;
               request_loadstate <= '1';
               load_buffer       <= '0';
            end if;
         end if;
      end if;
   end process;
  

end architecture;





