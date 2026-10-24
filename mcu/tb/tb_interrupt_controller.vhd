library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_interrupt_controller is
end entity;

architecture testbench of tb_interrupt_controller is

    component interrupt_controller
        port (
            clk_i             : in  std_logic;
            rst_i             : in  std_logic;
            inta_n_i          : in  std_logic;
            irq_service_pulse_i: in std_logic;
            irq_service_type_i: in  std_logic_vector(7 downto 0);
            event_i           : in  std_logic_vector(6 downto 0);
            mmio_write_i      : in  std_logic;
            cs_ie_i           : in  std_logic;
            cs_ifg_i          : in  std_logic;
            wdata_i           : in  std_logic_vector(7 downto 0);
            ie_rdata_o        : out std_logic_vector(7 downto 0);
            ifg_rdata_o       : out std_logic_vector(7 downto 0);
            type_rdata_o      : out std_logic_vector(7 downto 0);
            irq_pending_raw_o : out std_logic
        );
    end component;

    signal clk_i             : std_logic := '0';
    signal rst_i             : std_logic := '1';
    signal inta_n_i          : std_logic := '1';
    signal irq_service_pulse_i: std_logic := '0';
    signal irq_service_type_i : std_logic_vector(7 downto 0) := (others => '0');
    signal event_i           : std_logic_vector(6 downto 0) := (others => '0');
    signal mmio_write_i      : std_logic := '0';
    signal cs_ie_i           : std_logic := '0';
    signal cs_ifg_i          : std_logic := '0';
    signal wdata_i           : std_logic_vector(7 downto 0) := (others => '0');
    signal ie_rdata_o        : std_logic_vector(7 downto 0);
    signal ifg_rdata_o       : std_logic_vector(7 downto 0);
    signal type_rdata_o      : std_logic_vector(7 downto 0);
    signal irq_pending_raw_o : std_logic;

    constant CLK_PERIOD : time := 40 ns;

begin

    dut: interrupt_controller
    port map (
        clk_i             => clk_i,
        rst_i             => rst_i,
        inta_n_i          => inta_n_i,
        irq_service_pulse_i => irq_service_pulse_i,
        irq_service_type_i  => irq_service_type_i,
        event_i           => event_i,
        mmio_write_i      => mmio_write_i,
        cs_ie_i           => cs_ie_i,
        cs_ifg_i          => cs_ifg_i,
        wdata_i           => wdata_i,
        ie_rdata_o        => ie_rdata_o,
        ifg_rdata_o       => ifg_rdata_o,
        type_rdata_o      => type_rdata_o,
        irq_pending_raw_o => irq_pending_raw_o
    );

    clk_process: process
    begin
        clk_i <= '0';
        wait for CLK_PERIOD / 2;
        clk_i <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    stim_process: process
        type vector_array is array(0 to 5) of std_logic_vector(7 downto 0);
        constant EXPECTED_TYPES : vector_array := (
            x"08", x"0C", x"10", x"14", x"18", x"1C"
        );
        variable mask : std_logic_vector(7 downto 0);
        variable clr_mask : std_logic_vector(7 downto 0);
    begin
        -- Test Reset (active-high)
        rst_i <= '1';
        wait for 2 * CLK_PERIOD;
        rst_i <= '0';
        wait for CLK_PERIOD;

        ------------------------------------------------------------
        -- A. Each source individually
        ------------------------------------------------------------
        for i in 0 to 5 loop
            mask := (others => '0');
            mask(i) := '1';
            
            clr_mask := (others => '1');
            clr_mask(i) := '0';

            -- write IE
            cs_ie_i <= '1';
            mmio_write_i <= '1';
            wdata_i <= mask;
            wait for CLK_PERIOD;
            cs_ie_i <= '0';
            mmio_write_i <= '0';
            wait for CLK_PERIOD;

            -- pulse event
            event_i(i) <= '1';
            wait for CLK_PERIOD;
            event_i(i) <= '0';
            wait for CLK_PERIOD;

            -- check IFG, TYPE, raw
            assert ifg_rdata_o = mask report "A. IFG capture failed" severity failure;
            assert type_rdata_o = EXPECTED_TYPES(i) report "A. TYPE encode failed" severity failure;
            assert irq_pending_raw_o = '1' report "A. irq_pending_raw_o failed" severity failure;

            -- software clear
            cs_ifg_i <= '1';
            mmio_write_i <= '1';
            wdata_i <= clr_mask;
            wait for CLK_PERIOD;
            cs_ifg_i <= '0';
            mmio_write_i <= '0';
            wait for CLK_PERIOD;

            -- verify return to 0
            assert ifg_rdata_o = x"00" report "A. IFG clear failed" severity failure;
            assert type_rdata_o = x"00" report "A. TYPE not 0 after clear" severity failure;
            assert irq_pending_raw_o = '0' report "A. raw pending not 0 after clear" severity failure;
        end loop;

        -- Reset IE
        cs_ie_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"00";
        wait for CLK_PERIOD;
        cs_ie_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        ------------------------------------------------------------
        -- B. Write-one preserves
        ------------------------------------------------------------
        event_i(2) <= '1';
        wait for CLK_PERIOD;
        event_i(2) <= '0';
        wait for CLK_PERIOD;

        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"04"; -- Write 1 to the bit that is 1
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        assert ifg_rdata_o = x"04" report "B. Write-one preserve failed" severity failure;

        -- clear it
        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"FB";
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        ------------------------------------------------------------
        -- C. Enable already-pending event
        ------------------------------------------------------------
        -- IE=0 already
        event_i(3) <= '1';
        wait for CLK_PERIOD;
        event_i(3) <= '0';
        wait for CLK_PERIOD;

        assert ifg_rdata_o = x"08" report "C. IFG not set when IE=0" severity failure;
        assert irq_pending_raw_o = '0' report "C. raw pending should be 0" severity failure;

        cs_ie_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"08"; -- Enable it
        wait for CLK_PERIOD;
        cs_ie_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        assert type_rdata_o = x"14" report "C. TYPE immediately reflect failed" severity failure;
        assert irq_pending_raw_o = '1' report "C. raw pending immediately reflect failed" severity failure;

        -- clear it and IE
        cs_ifg_i <= '1';
        cs_ie_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"F7"; -- For IFG clear. Wait, they share wdata.
        -- let's do sequentially
        wait for CLK_PERIOD;
        
        cs_ifg_i <= '1';
        cs_ie_i <= '0';
        wdata_i <= x"F7";
        wait for CLK_PERIOD;
        
        cs_ifg_i <= '0';
        cs_ie_i <= '1';
        wdata_i <= x"00";
        wait for CLK_PERIOD;
        
        cs_ie_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        ------------------------------------------------------------
        -- D. Masked higher-priority source
        ------------------------------------------------------------
        -- Enable only bit 4 (lower priority)
        cs_ie_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"10";
        wait for CLK_PERIOD;
        cs_ie_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        -- Pending bit 1 (high priority) and bit 4
        event_i(1) <= '1';
        event_i(4) <= '1';
        wait for CLK_PERIOD;
        event_i <= (others => '0');
        wait for CLK_PERIOD;

        assert type_rdata_o = x"18" report "D. TYPE should select enabled lower priority" severity failure;

        -- Clear all
        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"00";
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        ------------------------------------------------------------
        -- E. Priority transition
        ------------------------------------------------------------
        -- Enable bits 2, 4, 5
        cs_ie_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"34";
        wait for CLK_PERIOD;
        cs_ie_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        -- Pend bits 2, 4, 5
        event_i(2) <= '1';
        event_i(4) <= '1';
        event_i(5) <= '1';
        wait for CLK_PERIOD;
        event_i <= (others => '0');
        wait for CLK_PERIOD;

        assert type_rdata_o = x"10" report "E. Initial priority transition failed" severity failure;

        -- Clear bit 2
        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"FB";
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        assert type_rdata_o = x"18" report "E. Transition 1 failed" severity failure;

        -- Clear bit 4
        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"EF";
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        assert type_rdata_o = x"1C" report "E. Transition 2 failed" severity failure;

        -- Clear bit 5
        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"DF";
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;

        assert type_rdata_o = x"00" report "E. Transition end failed" severity failure;

        ------------------------------------------------------------
        -- F. Simultaneous Hardware Set vs Software Clear
        ------------------------------------------------------------
        -- Write clear mask while hardware sets
        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"00"; -- Software clears all
        event_i(4) <= '1'; -- Hardware sets bit 4
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        event_i(4) <= '0';
        wait for CLK_PERIOD;

        assert ifg_rdata_o = x"10" report "F. Simultaneous set/clear failed (Hardware should win)" severity failure;

        ------------------------------------------------------------
        -- G. Hardware Auto-Clear
        ------------------------------------------------------------
        -- Pend all events
        event_i <= "0111111";
        wait for CLK_PERIOD;
        event_i <= (others => '0');
        wait for CLK_PERIOD;
        
        -- Auto-clear bit 0 (type 08)
        irq_service_pulse_i <= '1';
        irq_service_type_i <= x"08";
        wait for CLK_PERIOD;
        irq_service_pulse_i <= '0';
        wait for CLK_PERIOD;
        
        assert ifg_rdata_o(0) = '0' report "G. Auto-clear failed for type 08" severity failure;
        assert ifg_rdata_o(1) = '1' report "G. Auto-clear wrongly cleared bit 1" severity failure;
        
        -- Auto-clear bit 1 (type 0C)
        irq_service_pulse_i <= '1';
        irq_service_type_i <= x"0C";
        wait for CLK_PERIOD;
        irq_service_pulse_i <= '0';
        wait for CLK_PERIOD;
        
        assert ifg_rdata_o(1) = '0' report "G. Auto-clear failed for type 0C" severity failure;
        
        -- Auto-clear bit 2 (type 10)
        irq_service_pulse_i <= '1';
        irq_service_type_i <= x"10";
        wait for CLK_PERIOD;
        irq_service_pulse_i <= '0';
        wait for CLK_PERIOD;
        
        assert ifg_rdata_o(2) = '0' report "G. Auto-clear failed for type 10" severity failure;
        
        -- Verify KEYs do NOT auto-clear (types 14, 18, 1C -> bits 3, 4, 5)
        irq_service_pulse_i <= '1';
        irq_service_type_i <= x"14";
        wait for CLK_PERIOD;
        irq_service_type_i <= x"18";
        wait for CLK_PERIOD;
        irq_service_type_i <= x"1C";
        wait for CLK_PERIOD;
        irq_service_pulse_i <= '0';
        wait for CLK_PERIOD;
        
        assert ifg_rdata_o(3) = '1' report "G. Auto-clear wrongly cleared KEY1" severity failure;
        assert ifg_rdata_o(4) = '1' report "G. Auto-clear wrongly cleared KEY2" severity failure;
        assert ifg_rdata_o(5) = '1' report "G. Auto-clear wrongly cleared KEY3" severity failure;

        -- Reserved IE/IFG bits 7:6 cannot be written or raised.
        cs_ie_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"C0";
        wait for CLK_PERIOD;
        cs_ie_i <= '0';
        mmio_write_i <= '0';
        event_i(6) <= '1';
        wait for CLK_PERIOD;
        event_i(6) <= '0';
        wait for CLK_PERIOD;
        assert ie_rdata_o(7 downto 6) = "00" report "G. reserved IE bits are not zero" severity failure;
        assert ifg_rdata_o(7 downto 6) = "00" report "G. reserved IFG bits are not zero" severity failure;

        ------------------------------------------------------------
        -- H. Explicit Timer Specific Assertions
        ------------------------------------------------------------
        -- Clear all
        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"00";
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;
        
        -- timer event sets IFG bit 2 while IE bit 2 is zero
        -- IE is already 0 here.
        event_i(2) <= '1';
        wait for CLK_PERIOD;
        event_i(2) <= '0';
        wait for CLK_PERIOD;
        assert ifg_rdata_o(2) = '1' report "H. timer event did not set IFG bit 2 while IE=0" severity failure;
        
        -- Enable IE bit 2
        cs_ie_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"04";
        wait for CLK_PERIOD;
        cs_ie_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;
        
        -- timer TYPE = 0x10
        assert type_rdata_o = x"10" report "H. timer TYPE != 0x10" severity failure;
        
        -- timer has priority over KEY1
        -- Pend KEY1 (bit 3)
        event_i(3) <= '1';
        wait for CLK_PERIOD;
        event_i(3) <= '0';
        wait for CLK_PERIOD;
        -- Enable KEY1 IE
        cs_ie_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"0C";
        wait for CLK_PERIOD;
        cs_ie_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;
        
        -- Both Timer (bit 2) and KEY1 (bit 3) are pending and enabled.
        -- Timer should have priority.
        assert type_rdata_o = x"10" report "H. timer does not have priority over KEY1" severity failure;
        
        -- timer service clears IFG bit 3
        irq_service_pulse_i <= '1';
        irq_service_type_i <= x"10";
        wait for CLK_PERIOD;
        irq_service_pulse_i <= '0';
        wait for CLK_PERIOD;
        assert ifg_rdata_o(2) = '0' report "H. timer service did not clear IFG bit 2" severity failure;
        
        -- simultaneous timer service clear and new timer event: IFG bit 2 remains set
        -- Clear everything again
        cs_ifg_i <= '1';
        mmio_write_i <= '1';
        wdata_i <= x"00";
        wait for CLK_PERIOD;
        cs_ifg_i <= '0';
        mmio_write_i <= '0';
        wait for CLK_PERIOD;
        
        -- Pend timer
        event_i(2) <= '1';
        wait for CLK_PERIOD;
        event_i(2) <= '0';
        wait for CLK_PERIOD;
        
        -- Service pulse while NEW timer event arrives
        irq_service_pulse_i <= '1';
        irq_service_type_i <= x"10";
        event_i(2) <= '1';
        wait for CLK_PERIOD;
        irq_service_pulse_i <= '0';
        event_i(2) <= '0';
        wait for CLK_PERIOD;
        
        assert ifg_rdata_o(2) = '1' report "H. simultaneous service clear and new event failed (IFG 2 cleared!)" severity failure;

        report "PASS: tb_interrupt_controller" severity note;
        std.env.finish;
    end process;

    timeout_process: process
    begin
        wait for 5000 ns;
        report "Simulation timed out!" severity failure;
    end process;

end architecture testbench;
