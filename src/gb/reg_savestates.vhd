library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pBus_savestates.all;

package pReg_savestates is

   --   (                                                   adr   upper    lower    size   default)  

   -- cpu
   constant REG_SAVESTATE_GBSE            : regmap_type := (  0,   11,      0,        1, x"000000000000000F");
   constant REG_SAVESTATE_CPUREGS         : regmap_type := (  1,   63,      0,        1, x"0000000000000000");
   constant REG_SAVESTATE_T80_1           : regmap_type := (  2,   61,      0,        1, x"0000000000000000");
   constant REG_SAVESTATE_T80_2           : regmap_type := (  3,   50,      0,        1, x"00000000FFFF0000");
   constant REG_SAVESTATE_T80_3           : regmap_type := (  4,   57,      0,        1, x"020000801FE0FFFF");
   constant REG_SAVESTATE_T80_4           : regmap_type := (  5,   52,      0,        1, x"0001000000000000");

   -- components
   constant REG_SAVESTATE_Timer           : regmap_type := (  6,   46,      0,        1, x"0000000000000008");

   constant REG_SAVESTATE_HDMA            : regmap_type := (  7,   47,      0,        1, x"0000E00001FFFFF0");

   constant REG_SAVESTATE_Link            : regmap_type := (  8,   16,      0,        1, x"0000000000000000");

   constant REG_SAVESTATE_Video1          : regmap_type := (  9,   60,      0,        1, x"0000000000000000");
   constant REG_SAVESTATE_Video2          : regmap_type := ( 10,   63,      0,        1, x"00000000FFFFFC00");
   constant REG_SAVESTATE_BPalette        : regmap_type := ( 11,   63,      0,        8, x"0000000000000000");
   constant REG_SAVESTATE_OPalette        : regmap_type := ( 19,   63,      0,        8, x"0000000000000000");
   constant REG_SAVESTATE_Video3          : regmap_type := ( 27,   63,      0,        1, x"0000000000000000");

   constant REG_SAVESTATE_Sound1          : regmap_type := ( 28,   63,      0,        1, x"0000000000000000");
   constant REG_SAVESTATE_Sound2          : regmap_type := ( 29,   54,      0,        1, x"0000000000000000");
   constant REG_SAVESTATE_Sound3          : regmap_type := ( 30,   62,      0,        1, x"0000000000000000");
   
   constant REG_SAVESTATE_Wave1           : regmap_type := ( 33,   63,      0,        1, x"C32987D2AA340448");
   constant REG_SAVESTATE_Wave2           : regmap_type := ( 34,   63,      0,        1, x"ADE28B430B959506");   
   constant REG_SAVESTATE_Wave1_GBC       : regmap_type := ( 35,   63,      0,        1, x"FF00FF00FF00FF00");
   constant REG_SAVESTATE_Wave2_GBC       : regmap_type := ( 36,   63,      0,        1, x"FF00FF00FF00FF00");
   
   constant REG_SAVESTATE_Top             : regmap_type := ( 31,   56,      0,        1, x"0000000000800001");
   constant REG_SAVESTATE_Top2            : regmap_type := ( 38,   10,      0,        1, x"0000000000000000");
   constant REG_SAVESTATE_Ext             : regmap_type := ( 32,   15,      0,        1, x"0000000000000001");
   constant REG_SAVESTATE_Ext2            : regmap_type := ( 37,   63,      0,        1, x"0000000000000000");
   
end package;
