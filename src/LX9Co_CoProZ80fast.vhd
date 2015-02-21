library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity LX9CoProZ80fast is
    port (
        -- GOP Signals
        fastclk   : in    std_logic;
        test      : out   std_logic_vector(8 downto 1);
        sw        : in    std_logic_vector(2 downto 1);
        
        -- Tube signals (use 16 out of 22 DIL pins)
        h_phi2    : in    std_logic;  -- 1,2,12,21,23 are global clocks
        h_addr    : in    std_logic_vector(2 downto 0);
        h_data    : inout std_logic_vector(7 downto 0);
        h_rdnw    : in    std_logic;
        h_cs_b    : in    std_logic;
        h_rst_b   : in    std_logic;
        h_irq_b   : inout std_logic;


        -- Ram Signals
		ram_ub_b     : out   std_logic;
		ram_lb_b     : out   std_logic;
        ram_cs       : out   std_logic;
        ram_oe       : out   std_logic;
        ram_wr       : out   std_logic;
        ram_addr     : out   std_logic_vector (18 downto 0);
        ram_data     : inout std_logic_vector (7 downto 0)
    );
end LX9CoProZ80fast;

architecture BEHAVIORAL of LX9CoProZ80fast is
 
    component dcm_32_72
        port (
            CLKIN_IN  : in  std_logic;
            CLK0_OUT  : out std_logic;
            CLK0_OUT1 : out std_logic;
            CLK2X_OUT : out std_logic
        ); 
    end component;

    component tuberom_z80_banner
        port (
            CLK  : in  std_logic;
            ADDR : in  std_logic_vector(11 downto 0);
            SW   : in  std_logic_vector(1 downto 0);
            DATA : out std_logic_vector(7 downto 0));
    end component;

    component T80se
        port (
            RESET_n : in  std_logic;
            CLK_n   : in  std_logic;
            CLKEN   : in  std_logic;
            WAIT_n  : in  std_logic;
            INT_n   : in  std_logic;
            NMI_n   : in  std_logic;
            BUSRQ_n : in  std_logic;
            M1_n    : out std_logic;
            MREQ_n  : out std_logic;
            IORQ_n  : out std_logic;
            RD_n    : out std_logic;
            WR_n    : out std_logic;
            RFSH_n  : out std_logic;
            HALT_n  : out std_logic;
            BUSAK_n : out std_logic;
            A       : out std_logic_vector(15 downto 0);
            DI      : in  std_logic_vector(7 downto 0);
            DO      : out std_logic_vector(7 downto 0)
        );
    end component;
    
    component tube
        port(
            h_addr     : in    std_logic_vector(2 downto 0);
            h_cs_b     : in    std_logic;
            h_data     : inout std_logic_vector(7 downto 0);
            h_phi2     : in    std_logic;
            h_rdnw     : in    std_logic;
            h_rst_b    : in    std_logic;
            h_irq_b    : inout std_logic;
            p_addr     : in    std_logic_vector(2 downto 0);
            p_cs_b     : in    std_logic;
            p_data_in  : in    std_logic_vector(7 downto 0);
            p_data_out : out   std_logic_vector(7 downto 0);
            p_rdnw     : in    std_logic;
            p_phi2     : in    std_logic;
            p_rst_b    : out   std_logic;
            p_nmi_b    : inout std_logic;
            p_irq_b    : inout std_logic
          );
    end component;

    component RAM_64K
        port(
            clk     : in std_logic;
            we_uP   : in std_logic;
            ce      : in std_logic;
            addr_uP : in std_logic_vector(15 downto 0);
            D_uP    : in std_logic_vector(7 downto 0);          
            Q_uP    : out std_logic_vector(7 downto 0)
        );
    end component;

-------------------------------------------------
-- clock and reset signals
-------------------------------------------------

    signal cpu_clk       : std_logic;
    signal cpu_clken     : std_logic;
    signal bootmode      : std_logic;
    signal RSTn          : std_logic;
    signal RSTn_sync     : std_logic;
    signal clken_counter : std_logic_vector (3 downto 0);

-------------------------------------------------
-- parasite signals
-------------------------------------------------
    
    signal p_cs_b        : std_logic;
    signal tube_cs_b     : std_logic;
    signal p_data_out    : std_logic_vector (7 downto 0);

-------------------------------------------------
-- ram/rom signals
-------------------------------------------------

    signal ram_cs_b        : std_logic;
    signal ram_oe_int      : std_logic;
    signal ram_wr_int      : std_logic;	
    signal rom_cs_b        : std_logic;
    signal rom_data_out    : std_logic_vector (7 downto 0);
    signal ram_data_out    : std_logic_vector (7 downto 0);

-------------------------------------------------
-- cpu signals
-------------------------------------------------
    
    signal cpu_rd_n   : std_logic;
    signal cpu_wr_n   : std_logic;
    signal cpu_iorq_n : std_logic;
    signal cpu_mreq_n : std_logic;
    signal cpu_m1_n   : std_logic;
    signal cpu_addr   : std_logic_vector (15 downto 0);
    signal cpu_din    : std_logic_vector (7 downto 0);
    signal cpu_dout   : std_logic_vector (7 downto 0);
    signal cpu_IRQ_n  : std_logic;
    signal cpu_NMI_n  : std_logic;
    signal cpu_IRQ_n_sync  : std_logic;
    signal cpu_NMI_n_sync  : std_logic;

begin

---------------------------------------------------------------------
-- instantiated components
---------------------------------------------------------------------

    inst_dcm_32_72 : dcm_32_72 port map (
        CLKIN_IN  => fastclk,
        CLK0_OUT  => cpu_clk,
        CLK0_OUT1 => open,
        CLK2X_OUT => open
    );

    inst_tuberom : tuberom_z80_banner port map (
        CLK        => cpu_clk,
        ADDR       => cpu_addr(11 downto 0),
        SW         => sw(2 downto 1),
        DATA       => rom_data_out
    );

    inst_Z80 : T80se port map (
        RESET_n    => RSTn_sync,
        CLK_n      => cpu_clk,
        CLKEN      => cpu_clken,
        WAIT_n     => '1',
        INT_n      => cpu_IRQ_n_sync,
        NMI_n      => cpu_NMI_n_sync,
        BUSRQ_n    => '1',
        M1_n       => cpu_m1_n,
        MREQ_n     => cpu_mreq_n,
        IORQ_n     => cpu_iorq_n,
        RD_n       => cpu_rd_n,
        WR_n       => cpu_wr_n,
        RFSH_n     => open,
        HALT_n     => open,
        BUSAK_n    => open,
        A          => cpu_addr,
        DI         => cpu_din,
        DO         => cpu_dout
    );

    inst_tube: tube port map (
        h_addr     => h_addr,
        h_cs_b     => h_cs_b,
        h_data     => h_data,
        h_phi2     => h_phi2,
        h_rdnw     => h_rdnw,
        h_rst_b    => h_rst_b,
        h_irq_b    => h_irq_b,
        p_addr     => cpu_addr(2 downto 0),
        p_cs_b     => tube_cs_b,
        p_data_in  => cpu_dout,
        p_data_out => p_data_out,
        p_phi2     => cpu_clk,
        p_rdnw     => cpu_wr_n,
        p_rst_b    => RSTn,
        p_nmi_b    => cpu_NMI_n,
        p_irq_b    => cpu_IRQ_n
    );

    tube_cs_b <= not ((not p_cs_b) and cpu_clken);
    
    Inst_RAM_64K: RAM_64K PORT MAP(
        clk     => cpu_clk,
        we_uP   => ram_wr_int,
        ce      => '1',
        addr_uP => cpu_addr,
        D_uP    => cpu_dout,
        Q_uP    => ram_data_out
    );

    p_cs_b <= '0' when cpu_mreq_n = '1' and cpu_iorq_n = '0' and cpu_addr(7 downto 3) = "00000" else '1';
    
    rom_cs_b <= '0' when cpu_mreq_n = '0' and cpu_rd_n = '0' and bootmode = '1' else '1';
    
    ram_cs_b <= '0' when cpu_mreq_n = '0' and rom_cs_b = '1' else '1';
    
    ram_wr_int <= ((not ram_cs_b) and (not cpu_wr_n) and cpu_clken);

    cpu_din <=
        p_data_out   when p_cs_b = '0' else
        rom_data_out when rom_cs_b = '0' else
        ram_data_out when ram_cs_b = '0' else
        x"fe";

--------------------------------------------------------
-- external Ram unused
--------------------------------------------------------
	ram_ub_b <= '1';
	ram_lb_b <= '1';
	ram_cs <= '1';
	ram_oe <= '1';
	ram_wr <= '1';
	ram_addr  <= (others => '1');
	ram_data  <= (others => '1');

--------------------------------------------------------
-- test signals
--------------------------------------------------------

    test(8) <= RSTn_sync;
    test(7) <= ram_wr_int;
    test(6) <= CPU_IRQ_n;
    test(5) <= p_cs_b;
    test(4) <= cpu_addr(2);
    test(3) <= cpu_addr(1);
    test(2) <= cpu_addr(0);
    test(1) <= p_data_out(7);

--------------------------------------------------------
-- boot mode generator
--------------------------------------------------------

    boot_gen : process(cpu_clk, RSTn_sync)
    begin
        if RSTn_sync = '0' then
            bootmode <= '1';
        elsif rising_edge(cpu_clk) then
            if (cpu_mreq_n = '0' and cpu_m1_n = '0') then
                if (cpu_addr = x"0066") then
                    bootmode <= '1';
                elsif cpu_addr(15) = '1' then
                    bootmode <= '0';
                end if;
            end if;
        end if;
    end process;

--------------------------------------------------------
-- synchronize interrupts etc into Z80 core
--------------------------------------------------------

    sync_gen : process(cpu_clk, RSTn_sync)
    begin
        if RSTn_sync = '0' then
            cpu_NMI_n_sync <= '1';
            cpu_IRQ_n_sync <= '1';
        elsif rising_edge(cpu_clk) then
            if (cpu_clken = '1') then
                cpu_NMI_n_sync <= cpu_NMI_n;
                cpu_IRQ_n_sync <= cpu_IRQ_n;            
            end if;
        end if;
    end process;
    
--------------------------------------------------------
-- clock enable generator
-- 00 - 36MHz = 72 / 2
-- 01 - 24MHz = 72 / 3
-- 10 - 12MHz = 72 / 6
-- 11 - 08MHz = 72 / 9
--------------------------------------------------------

    clk_gen : process(cpu_clk)
    begin
        if rising_edge(cpu_clk) then
            case "00"&sw is
               when x"0"   =>
                   if (clken_counter = 1) then
                       clken_counter <= (others => '0');
                   else
                       clken_counter <= clken_counter + 1;
                   end if;
               when x"1"   =>
                   if (clken_counter = 2) then
                       clken_counter <= (others => '0');
                   else
                       clken_counter <= clken_counter + 1;
                   end if;
               when x"2"   =>
                   if (clken_counter = 5) then
                       clken_counter <= (others => '0');
                   else
                       clken_counter <= clken_counter + 1;
                   end if;
               when others   =>
                   if (clken_counter = 8) then
                       clken_counter <= (others => '0');
                   else
                       clken_counter <= clken_counter + 1;
                   end if;
            end case;
            cpu_clken     <= not clken_counter(3) and not clken_counter(2) and not clken_counter(1) and not clken_counter(0);
            RSTn_sync     <= RSTn;
        end if;
    end process;

end BEHAVIORAL;


