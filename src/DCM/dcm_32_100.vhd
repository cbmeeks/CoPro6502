library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.Vcomponents.all;

entity dcm_32_100 is
    port (CLKIN_IN  : in  std_logic;
          CLK0_OUT  : out std_logic;
          CLK0_OUT1 : out std_logic;
          CLK2X_OUT : out std_logic); 
end dcm_32_100;

architecture BEHAVIORAL of dcm_32_100 is
    signal CLKFX_BUF   : std_logic;
    signal CLK2X_BUF   : std_logic;
    signal CLKIN_IBUFG : std_logic;
    signal GND_BIT     : std_logic;
begin

    GND_BIT <= '0';

    CLKFX_BUFG_INST : BUFG
        port map (I => CLKFX_BUF, O => CLK0_OUT);
    
    CLK2X_BUFG_INST : BUFG
        port map (I => CLK2X_BUF, O => CLK2X_OUT);

    DCM_INST : DCM
        generic map(CLK_FEEDBACK          => "NONE",
                    CLKDV_DIVIDE          => 4.0,  -- 100.00 = 32.000 * 25/8
                    CLKFX_MULTIPLY        => 25,
                    CLKFX_DIVIDE          => 8,
                    CLKIN_DIVIDE_BY_2     => false,
                    CLKIN_PERIOD          => 31.25,
                    CLKOUT_PHASE_SHIFT    => "NONE",
                    DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
                    DFS_FREQUENCY_MODE    => "LOW",
                    DLL_FREQUENCY_MODE    => "LOW",
                    DUTY_CYCLE_CORRECTION => true,
                    FACTORY_JF            => x"C080",
                    PHASE_SHIFT           => 0,
                    STARTUP_WAIT          => false)
        port map (CLKFB    => GND_BIT,
                  CLKIN    => CLKIN_IN,
                  DSSEN    => GND_BIT,
                  PSCLK    => GND_BIT,
                  PSEN     => GND_BIT,
                  PSINCDEC => GND_BIT,
                  RST      => GND_BIT,
                  CLKDV    => open,
                  CLKFX    => CLKFX_BUF,
                  CLKFX180 => open,
                  CLK0     => open,
                  CLK2X    => CLK2X_BUF,
                  CLK2X180 => open,
                  CLK90    => open,
                  CLK180   => open,
                  CLK270   => open,
                  LOCKED   => open,
                  PSDONE   => open,
                  STATUS   => open);

end BEHAVIORAL;
