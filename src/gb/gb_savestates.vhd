library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pBus_savestates.all;

entity gb_savestates is
   port 
   (
      clk                     : in     std_logic;  
      reset_in                : in     std_logic;
      reset_out               : out    std_logic := '0';
            
      load_done               : out    std_logic := '0';
            
      increaseSSHeaderCount   : in     std_logic; 
      save                    : in     std_logic;  
      load                    : in     std_logic;
      savestate_address       : in     integer;
      savestate_busy          : out    std_logic;
      
      cart_ram_size           : in     std_logic_vector(7 downto 0);
      
      lcd_vsync               : in     std_logic;
            
      BUS_Din                 : out    std_logic_vector(BUS_buswidth-1 downto 0) := (others => '0');
      BUS_Adr                 : buffer std_logic_vector(BUS_busadr-1 downto 0) := (others => '0');
      BUS_wren                : out    std_logic := '0';
      BUS_rst                 : out    std_logic := '0';
      BUS_Dout                : in     std_logic_vector(BUS_buswidth-1 downto 0) := (others => '0');
            
      loading_savestate       : out    std_logic := '0';
      saving_savestate        : out    std_logic := '0';
      sleep_savestate         : out    std_logic := '0';
      clock_ena_in            : in     std_logic;
            
      Save_RAMAddr            : buffer std_logic_vector(19 downto 0) := (others => '0');
      Save_RAMWrEn            : out    std_logic_vector(4 downto 0) := (others => '0');
      Save_RAMWriteData       : out    std_logic_vector(7 downto 0) := (others => '0');
      Save_RAMReadData_WRAM   : in     std_logic_vector(7 downto 0);
      Save_RAMReadData_VRAM   : in     std_logic_vector(7 downto 0);
      Save_RAMReadData_ORAM   : in     std_logic_vector(7 downto 0);
      Save_RAMReadData_ZRAM   : in     std_logic_vector(7 downto 0);
      Save_RAMReadData_CRAM   : in     std_logic_vector(7 downto 0);
      
      bus_out_Din             : out    std_logic_vector(63 downto 0) := (others => '0');
      bus_out_Dout            : in     std_logic_vector(63 downto 0);
      bus_out_Adr             : buffer std_logic_vector(25 downto 0) := (others => '0');
      bus_out_rnw             : out    std_logic := '0';
      bus_out_ena             : out    std_logic := '0';
      bus_out_be              : out    std_logic_vector(7 downto 0) := (others => '0');
      bus_out_done            : in     std_logic
   );
end entity;

architecture arch of gb_savestates is

   constant STATESIZE      : integer := 16#B0CA#;
   
   constant SETTLECOUNT    : integer := 100;
   constant HEADERCOUNT    : integer := 2;
   constant INTERNALSCOUNT : integer := 64; -- not all used, room for some more
   
   constant SAVETYPESCOUNT : integer := 5;
   signal savetype_counter : integer range 0 to SAVETYPESCOUNT;
   type t_savetypes is array(0 to SAVETYPESCOUNT - 1) of integer;
   signal savetypes : t_savetypes := 
   (
      32768, -- RAM
      16384, -- VRAM
      160,   -- OAM
      128,   -- ZeroPage
      131072 -- Saveram -> overwritten depending on cart_ram_size
   );

   type tstate is
   (
      IDLE,
      SAVE_WAITVSYNC,
      SAVE_WAITSETTLE,
      SAVEINTERNALS_WAIT,
      SAVEINTERNALS_WRITE,
      SAVEMEMORY_NEXT,
      SAVEMEMORY_FIRST,
      SAVEMEMORY_READ,
      SAVEMEMORY_WRITE,
      SAVESIZEAMOUNT,
      LOAD_WAITSETTLE,
      LOAD_HEADERAMOUNTCHECK,
      LOADINTERNALS_READ,
      LOADINTERNALS_WRITE,
      LOADMEMORY_NEXT,
      LOADMEMORY_READ,
      LOADMEMORY_WRITE
   );
   signal state : tstate := IDLE;
   
   signal count               : integer range 0 to 131072 := 0;
   signal maxcount            : integer range 0 to 131072;
               
   signal settle              : integer range 0 to SETTLECOUNT := 0;
   
   signal bytecounter         : integer range 0 to 7 := 0;
   signal Save_RAMReadData    : std_logic_vector(7 downto 0);
   signal RAMAddrNext         : std_logic_vector(19 downto 0) := (others => '0');
   
   signal header_amount       : unsigned(31 downto 0) := (others => '0');

begin 

   savestate_busy <= '0' when state = IDLE else '1';
   
   Save_RAMReadData <= Save_RAMReadData_WRAM when savetype_counter = 0 else
                       Save_RAMReadData_VRAM when savetype_counter = 1 else
                       Save_RAMReadData_ORAM when savetype_counter = 2 else
                       Save_RAMReadData_ZRAM when savetype_counter = 3 else
                       Save_RAMReadData_CRAM;

   process (clk)
   begin
      if rising_edge(clk) then
   
         Save_RAMWrEn <= (others => '0');
         bus_out_ena   <= '0';
         BUS_wren      <= '0';
         BUS_rst       <= '0';
         reset_out     <= '0';
         load_done     <= '0';
         
         bus_out_be    <= x"FF";
         
         case (cart_ram_size) is
            when x"00"  => savetypes(4) <=    512; -- for MBC2
            when x"01"  => savetypes(4) <=   2048; -- 2   KByte
            when x"02"  => savetypes(4) <=   8192; -- 8   KByte
            when x"03"  => savetypes(4) <=  32768; -- 32  KByte
            when others => savetypes(4) <= 131072; -- 128 KByte 
         end case;
   
         case state is
         
            when IDLE =>
               savetype_counter <= 0;
               if (reset_in = '1') then
                  reset_out <= '1';
				  BUS_rst   <= '1';
               elsif (save = '1') then
                  state                <= SAVE_WAITVSYNC;
                  header_amount        <= header_amount + 1;
               elsif (load = '1') then
                  state                <= LOAD_WAITSETTLE;
                  settle               <= 0;
                  sleep_savestate      <= '1';
               end if;
               
            -- #################
            -- SAVE
            -- #################
            
            when SAVE_WAITVSYNC =>
               if (lcd_vsync = '1') then
                  state                <= SAVE_WAITSETTLE;
                  settle               <= 0;
                  sleep_savestate      <= '1';
               end if;
            
            when SAVE_WAITSETTLE =>
               if (clock_ena_in = '1') then
                  settle <= 0;
               elsif (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               else
                  state            <= SAVEINTERNALS_WAIT;
                  bus_out_Adr      <= std_logic_vector(to_unsigned(savestate_address + HEADERCOUNT, 26));
                  bus_out_rnw      <= '0';
                  BUS_adr          <= (others => '0');
                  count            <= 1;
                  saving_savestate <= '1';
               end if;            
            
            when SAVEINTERNALS_WAIT =>
               bus_out_Din    <= BUS_Dout;
               bus_out_ena    <= '1';
               state          <= SAVEINTERNALS_WRITE;
            
            when SAVEINTERNALS_WRITE => 
               if (bus_out_done = '1') then
                  bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < INTERNALSCOUNT) then
                     state       <= SAVEINTERNALS_WAIT;
                     count       <= count + 1;
                     BUS_adr     <= std_logic_vector(unsigned(BUS_adr) + 1);
                  else 
                     state       <= SAVEMEMORY_NEXT;
                     count       <= 8;
                  end if;
               end if;
            
            when SAVEMEMORY_NEXT =>
               if (savetype_counter < SAVETYPESCOUNT) then
                  state        <= SAVEMEMORY_FIRST;
                  bytecounter  <= 0;
                  count        <= 8;
                  maxcount     <= savetypes(savetype_counter);
                  Save_RAMAddr <= (others => '0');
               else
                  state          <= SAVESIZEAMOUNT;
                  bus_out_Adr    <= std_logic_vector(to_unsigned(savestate_address, 26));
                  bus_out_Din    <= std_logic_vector(to_unsigned(STATESIZE, 32)) & std_logic_vector(header_amount);
                  bus_out_ena    <= '1';
                  if (increaseSSHeaderCount = '0') then
                     bus_out_be  <= x"F0";
                  end if;
               end if;
               
            when SAVEMEMORY_FIRST =>
               state          <= SAVEMEMORY_READ;
               Save_RAMAddr   <= std_logic_vector(unsigned(Save_RAMAddr) + 1);         
            
            when SAVEMEMORY_READ =>
               bus_out_Din(bytecounter * 8 + 7 downto bytecounter * 8)  <= Save_RAMReadData;
               if (bytecounter < 7) then
                  bytecounter    <= bytecounter + 1;
                  Save_RAMAddr   <= std_logic_vector(unsigned(Save_RAMAddr) + 1);
               else
                  state          <= SAVEMEMORY_WRITE;
                  bus_out_ena    <= '1';
               end if;
               
            when SAVEMEMORY_WRITE =>
               if (bus_out_done = '1') then
                  bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < maxcount) then
                     state        <= SAVEMEMORY_FIRST;
                     bytecounter  <= 0;
                     count        <= count + 8;
                  else 
                     savetype_counter <= savetype_counter + 1;
                     state            <= SAVEMEMORY_NEXT;
                  end if;
               end if;
            
            when SAVESIZEAMOUNT =>
               if (bus_out_done = '1') then
                  state            <= IDLE;
                  saving_savestate <= '0';
                  sleep_savestate  <= '0';
               end if;
            
            
            -- #################
            -- LOAD
            -- #################
            
            when LOAD_WAITSETTLE =>
               if (clock_ena_in = '1') then
                  settle <= 0;
               elsif (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               else
                  state                <= LOAD_HEADERAMOUNTCHECK;
                  bus_out_Adr          <= std_logic_vector(to_unsigned(savestate_address, 26));
                  bus_out_rnw          <= '1';
                  bus_out_ena          <= '1';
               end if;
               
            when LOAD_HEADERAMOUNTCHECK =>
               if (bus_out_done = '1') then
                  if (bus_out_Dout(63 downto 32) = std_logic_vector(to_unsigned(STATESIZE, 32))) then
                     header_amount        <= unsigned(bus_out_Dout(31 downto 0));
                     state                <= LOADINTERNALS_READ;
                     bus_out_Adr          <= std_logic_vector(to_unsigned(savestate_address + HEADERCOUNT, 26));
                     bus_out_ena          <= '1';
                     BUS_adr              <= (others => '0');
                     count                <= 1;
                     loading_savestate    <= '1';
                  else
                     state                <= IDLE;
                     sleep_savestate      <= '0';
                  end if;
               end if;
            
            when LOADINTERNALS_READ =>
               if (bus_out_done = '1') then
                  state           <= LOADINTERNALS_WRITE;
                  BUS_Din         <= bus_out_Dout;
                  BUS_wren        <= '1';
               end if;
            
            when LOADINTERNALS_WRITE => 
               bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
               if (count < INTERNALSCOUNT) then
                  state          <= LOADINTERNALS_READ;
                  count          <= count + 1;
                  bus_out_ena    <= '1';
                  BUS_adr        <= std_logic_vector(unsigned(BUS_adr) + 1);
               else 
                  state              <= LOADMEMORY_NEXT;
                  count              <= 8;
               end if;
            
            when LOADMEMORY_NEXT =>
               if (savetype_counter < SAVETYPESCOUNT) then
                  state          <= LOADMEMORY_READ;
                  count          <= 8;
                  maxcount       <= savetypes(savetype_counter);
                  Save_RAMAddr   <= (others => '0');
                  RAMAddrNext    <= (others => '0');
                  bytecounter    <= 0;
                  bus_out_ena    <= '1';
               else
                  state             <= IDLE;
                  reset_out         <= '1';
                  loading_savestate <= '0';
                  sleep_savestate   <= '0';
                  load_done         <= '1';
               end if;
            
            when LOADMEMORY_READ =>
               if (bus_out_done = '1') then
                  state             <= LOADMEMORY_WRITE;
               end if;
               
            when LOADMEMORY_WRITE =>
               RAMAddrNext                    <= std_logic_vector(unsigned(RAMAddrNext) + 1);
               Save_RAMAddr                   <= RAMAddrNext;
               Save_RAMWrEn(savetype_counter) <= '1';
               Save_RAMWriteData              <= bus_out_Dout(bytecounter * 8 + 7 downto bytecounter * 8);
               if (bytecounter < 7) then
                  bytecounter       <= bytecounter + 1;
               else
                  bus_out_Adr  <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < maxcount) then
                     state          <= LOADMEMORY_READ;
                     count          <= count + 8;
                     bytecounter    <= 0;
                     bus_out_ena    <= '1';
                  else 
                     savetype_counter <= savetype_counter + 1;
                     state            <= LOADMEMORY_NEXT;
                  end if;
               end if;
         
         end case;
         
      end if;
   end process;
   

end architecture;





