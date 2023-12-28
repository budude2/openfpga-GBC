library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity gb_statemanager is
   generic
   (
      Softmap_SaveState_ADDR   : integer; -- count:  262144    -- 256 Kbyte Data for Savestate
      Softmap_Rewind_ADDR      : integer  -- count:  262144*128 -- 128*256 Kbyte Data for Savestates
   );
   port 
   (
      clk                 : in    std_logic; 
      reset               : in    std_logic;

      rewind_on           : in    std_logic;
      rewind_active       : in    std_logic;
      
      savestate_number    : in    integer;
      save                : in    std_logic;  
      load                : in    std_logic;
      
      sleep_rewind        : out   std_logic := '0';
      vsync               : in    std_logic;  
      
      request_savestate   : out   std_logic := '0';
      request_loadstate   : out   std_logic := '0';
      request_address     : out   integer;
      request_busy        : in    std_logic
   );
end entity;

architecture arch of gb_statemanager is

   constant SAVESTATESIZE : integer := 16#10000#; -- 65536 Dwords = 256kbyte
   constant REWIND_COUNT  : integer := 128;
   constant TIME_CAPTURE  : integer := 10000000; -- 320 ms       sim 1000000;
   constant TIME_REWIND   : integer :=  5000000; -- 160 ms       sim 1200000;

   signal save_1         : std_logic := '0';
   signal load_1         : std_logic := '0';
   signal save_buffer    : std_logic := '0';
   signal load_buffer    : std_logic := '0';
   
   signal rewind_enabled : std_logic := '0';
   signal rewind_load_next : std_logic := '0';
   
   signal timer_rewind   : integer range 0 to TIME_CAPTURE := 0;
   signal rewind_slow    : integer range 0 to TIME_REWIND := 0;
   signal savestatecount : integer range 0 to REWIND_COUNT := 0;
   signal savestatepos   : integer range 0 to REWIND_COUNT - 1 := 0;
   
   signal vsync_counter  : integer range 0 to 2 := 0;
   
   signal vsync_1 : std_logic;

begin 
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         request_savestate <= '0';
         request_loadstate <= '0';
         rewind_load_next  <= '0';
 
         vsync_1 <= vsync;
      
         save_1 <= save; 
         if (save = '1' and save_1 = '0') then
            save_buffer <= '1';
         end if;
         
         load_1 <= load;
         if (load = '1' and load_1 = '0') then
            load_buffer <= '1';
         end if;
         
         if (rewind_on = '0' or reset = '1') then
            rewind_enabled <= '0';
         end if;
         
         if (rewind_active = '0') then
            rewind_slow <= 0;
         elsif (rewind_slow < TIME_REWIND) then
            rewind_slow <= rewind_slow + 1;
         end if;
         
         if (rewind_active = '1') then
            timer_rewind <= 0;
         elsif (timer_rewind < TIME_CAPTURE) then
            timer_rewind <= timer_rewind + 1;
         end if;
         
         if (vsync_counter < 2 and vsync = '1' and vsync_1 = '0') then
            vsync_counter <= vsync_counter + 1;
         end if;
         
         sleep_rewind <= '0';
         if (vsync_counter = 2 and rewind_active = '1') then
            sleep_rewind <= '1';
         end if;
         
         if (reset = '0' and request_busy = '0') then
            
            if (save_buffer = '1') then
               request_address   <= Softmap_SaveState_ADDR + (savestate_number * SAVESTATESIZE);
               request_savestate <= '1';
               save_buffer       <= '0';
            elsif (load_buffer = '1') then
               request_address   <= Softmap_SaveState_ADDR + (savestate_number * SAVESTATESIZE);
               request_loadstate <= '1';
               load_buffer       <= '0';
            elsif (rewind_enabled = '0' and rewind_on = '1') then
               request_address   <= Softmap_Rewind_ADDR;
               request_savestate <= '1';
               rewind_enabled    <= '1';
               timer_rewind      <= 0;
               savestatecount    <= 1;
               savestatepos      <= 1;
            elsif (rewind_enabled = '1' and timer_rewind = TIME_CAPTURE) then
               request_address   <= Softmap_Rewind_ADDR + (savestatepos * SAVESTATESIZE);
               request_savestate <= '1';
               timer_rewind      <= 0;
               if (savestatecount < REWIND_COUNT) then
                  savestatecount <= savestatecount + 1;
               end if;
               if (savestatepos < (REWIND_COUNT - 1)) then
                  savestatepos <= savestatepos + 1;
               else
                  savestatepos <= 0;
               end if;
            elsif (rewind_enabled = '1' and rewind_slow = TIME_REWIND) then
               if (savestatecount > 1) then
                  savestatecount <= savestatecount - 1;
                  if (savestatepos > 0) then
                     savestatepos <= savestatepos - 1;
                  else
                     savestatepos <= REWIND_COUNT - 1;
                  end if;
                  rewind_load_next <= '1';
               end if;
               rewind_slow <= 0;
            elsif (rewind_load_next = '1') then
               request_address   <= Softmap_Rewind_ADDR + (savestatepos * SAVESTATESIZE);
               request_loadstate <= '1';
               vsync_counter     <= 0;
            end if;
            
         end if;

      end if;
   end process;
  

end architecture;





