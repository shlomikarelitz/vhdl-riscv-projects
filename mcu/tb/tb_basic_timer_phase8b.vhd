library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_basic_timer_phase8b is
end tb_basic_timer_phase8b;

architecture sim of tb_basic_timer_phase8b is
    component basic_timer
        port (
            clk_i          : in  std_logic;
            rst_i          : in  std_logic;
            mmio_write_i   : in  std_logic;
            wdata_i        : in  std_logic_vector(31 downto 0);
            cs_btctl1_i    : in  std_logic;
            cs_btctl2_i    : in  std_logic;
            cs_btcmpr0_i   : in  std_logic;
            cs_btcmpr1_i   : in  std_logic;
            capin1_i       : in  std_logic;
            capin2_i       : in  std_logic;
            pwmout_o       : out std_logic;
            btctl1_o       : out std_logic_vector(7 downto 0);
            btctl2_o       : out std_logic_vector(7 downto 0);
            btcmpr0_o      : out std_logic_vector(31 downto 0);
            btcmpr1_o      : out std_logic_vector(31 downto 0);
            btcapr_o       : out std_logic_vector(31 downto 0);
            timer_event_o  : out std_logic
        );
    end component;

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal mmio_write   : std_logic := '0';
    signal wdata        : std_logic_vector(31 downto 0) := (others => '0');
    signal cs_btctl1    : std_logic := '0';
    signal cs_btctl2    : std_logic := '0';
    signal cs_btcmpr0   : std_logic := '0';
    signal cs_btcmpr1   : std_logic := '0';
    signal capin1       : std_logic := '0';
    signal capin2       : std_logic := '0';
    signal pwmout       : std_logic;
    signal btctl1       : std_logic_vector(7 downto 0);
    signal btctl2       : std_logic_vector(7 downto 0);
    signal btcmpr0      : std_logic_vector(31 downto 0);
    signal btcmpr1      : std_logic_vector(31 downto 0);
    signal btcapr       : std_logic_vector(31 downto 0);
    signal timer_event  : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin
    clk <= not clk after CLK_PERIOD / 2;

    uut: basic_timer port map (
        clk_i => clk, rst_i => rst, mmio_write_i => mmio_write, wdata_i => wdata,
        cs_btctl1_i => cs_btctl1, cs_btctl2_i => cs_btctl2, cs_btcmpr0_i => cs_btcmpr0, cs_btcmpr1_i => cs_btcmpr1,
        capin1_i => capin1, capin2_i => capin2, pwmout_o => pwmout,
        btctl1_o => btctl1, btctl2_o => btctl2, btcmpr0_o => btcmpr0, btcmpr1_o => btcmpr1,
        btcapr_o => btcapr, timer_event_o => timer_event
    );

    stim_proc: process
        alias uut_equ0_pulse : std_logic is <<signal .tb_basic_timer_phase8b.uut.equ0_pulse : std_logic>>;
        alias uut_equ1_pulse : std_logic is <<signal .tb_basic_timer_phase8b.uut.equ1_pulse : std_logic>>;
        alias uut_btcnt : std_logic_vector(31 downto 0) is <<signal .tb_basic_timer_phase8b.uut.btcnt : std_logic_vector(31 downto 0)>>;
        alias uut_btcl0 : std_logic_vector(31 downto 0) is <<signal .tb_basic_timer_phase8b.uut.btcl0 : std_logic_vector(31 downto 0)>>;
        alias uut_btcl1 : std_logic_vector(31 downto 0) is <<signal .tb_basic_timer_phase8b.uut.btcl1 : std_logic_vector(31 downto 0)>>;
        alias uut_capin1_sync_stage1 : std_logic is <<signal .tb_basic_timer_phase8b.uut.capin1_sync_stage1 : std_logic>>;
        alias uut_capin1_sync_stage2 : std_logic is <<signal .tb_basic_timer_phase8b.uut.capin1_sync_stage2 : std_logic>>;
        alias uut_capin2_sync_stage1 : std_logic is <<signal .tb_basic_timer_phase8b.uut.capin2_sync_stage1 : std_logic>>;
        alias uut_capin2_sync_stage2 : std_logic is <<signal .tb_basic_timer_phase8b.uut.capin2_sync_stage2 : std_logic>>;
        alias uut_previous_capture_level : std_logic is <<signal .tb_basic_timer_phase8b.uut.previous_capture_level : std_logic>>;
        alias uut_capture_pulse : std_logic is <<signal .tb_basic_timer_phase8b.uut.capture_pulse : std_logic>>;

        procedure write_reg(addr: std_logic_vector(31 downto 0); signal cs: out std_logic; wdata_val: std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            cs <= '1';
            wdata <= wdata_val;
            mmio_write <= '1';
            wait until rising_edge(clk);
            cs <= '0';
            mmio_write <= '0';
        end procedure;

        procedure wait_pulse(signal p: in std_logic; max_clks: integer; msg: string) is
            variable found : boolean := false;
        begin
            for i in 1 to max_clks loop
                wait until rising_edge(clk);
                wait for 1 ns;
                if p = '1' then
                    found := true;
                    exit;
                end if;
            end loop;
            assert found report msg severity failure;
        end procedure;

        variable saved_cnt : std_logic_vector(31 downto 0);
        variable saved_capr : std_logic_vector(31 downto 0);
        variable expected_pre_cnt : std_logic_vector(31 downto 0);
        variable expected_cnt1 : std_logic_vector(31 downto 0);
        variable expected_cnt2 : std_logic_vector(31 downto 0);
        variable expected_falling_cnt : std_logic_vector(31 downto 0);
        variable expected_capin2_cnt : std_logic_vector(31 downto 0);
        variable found_flag : boolean;
    begin
        rst <= '1';
        wait for 2 * CLK_PERIOD;
        rst <= '0';
        wait until falling_edge(clk);
        assert pwmout = '0' report "reset pwmout_o = 0" severity failure;

        -- Test 1: Mode 0 EQU0 sets, EQU1 clears
        write_reg(x"00000000", cs_btcmpr0, x"00000008");
        write_reg(x"00000000", cs_btcmpr1, x"00000004");
        write_reg(x"00000000", cs_btctl1, x"00000004"); -- BTCLR=1, Mode=0, btouten=0

        wait_pulse(uut_equ1_pulse, 20, "Mode 0 EQU1 pulse timeout");
        assert pwmout = '0' report "Mode 0 EQU1 clears" severity failure;

        wait_pulse(uut_equ0_pulse, 20, "Mode 0 EQU0 pulse timeout");
        assert pwmout = '1' report "Mode 0 EQU0 sets" severity failure;

        wait_pulse(uut_equ1_pulse, 20, "Mode 0 EQU1 repeat pulse timeout");
        assert clk = '1' report "output changes only after an MCLK rising edge" severity failure;
        assert pwmout = '0' report "later valid compare changes output" severity failure;
        assert pwmout'last_event >= 1 ns report "no output event between MCLK rising edges" severity failure;

        -- Test 2: Mode 1 EQU0 clears, EQU1 sets
        write_reg(x"00000000", cs_btctl1, x"00000084"); -- BTCLR=1, Mode=1 (bit 7=1)
        wait_pulse(uut_equ1_pulse, 20, "Mode 1 EQU1 pulse timeout");
        assert pwmout = '1' report "Mode 1 EQU1 sets" severity failure;
        wait_pulse(uut_equ0_pulse, 20, "Mode 1 EQU0 pulse timeout");
        assert pwmout = '0' report "Mode 1 EQU0 clears" severity failure;

        -- Test 3: Simultaneous EQU0/EQU1 uses EQU1 priority
        write_reg(x"00000000", cs_btcmpr0, x"00000008");
        write_reg(x"00000000", cs_btcmpr1, x"00000008");
        write_reg(x"00000000", cs_btctl1, x"00000084"); -- BTCLR=1, Mode=1
        wait_pulse(uut_equ0_pulse, 20, "Simultaneous EQU pulse timeout");
        assert uut_equ0_pulse = '1' and uut_equ1_pulse = '1' report "both equality pulses observed" severity failure;
        assert pwmout = '1' report "simultaneous EQU0/EQU1 uses EQU1 priority" severity failure;

        -- Test 4: BTOUTEN and BTHOLD
        write_reg(x"00000000", cs_btcmpr0, x"0000000A");
        write_reg(x"00000000", cs_btcmpr1, x"00000005");
        write_reg(x"00000000", cs_btctl1, x"00000044"); -- BTOUTEN=1 (bit 6=1), BTCLR, Mode=0

        wait_pulse(uut_equ1_pulse, 20, "BTOUTEN EQU1 pulse timeout");
        assert pwmout = '1' report "BTOUTEN=1 holds output" severity failure;

        wait_pulse(uut_equ0_pulse, 20, "BTOUTEN EQU0 pulse timeout");
        assert pwmout = '1' report "counter and EQU logic continue while BTOUTEN=1" severity failure;

        write_reg(x"00000000", cs_btctl1, x"00000000"); -- clear BTOUTEN
        wait for 1 ns;
        assert pwmout = '1' report "releasing BTOUTEN does not immediately change output" severity failure;

        -- BTHOLD
        wait_pulse(uut_equ1_pulse, 20, "BTOUTEN release EQU1 pulse timeout");
        assert pwmout = '0' report "later valid compare changes output" severity failure;

        write_reg(x"00000000", cs_btctl1, x"00000020"); -- BTHOLD=1
        wait until rising_edge(clk); wait for 1 ns;
        saved_cnt := uut_btcnt;
        wait for 8 * CLK_PERIOD;
        wait for 1 ns;
        assert uut_btcnt = saved_cnt report "BTHOLD freezes exact BTCNT" severity failure;
        assert uut_equ0_pulse = '0' and uut_equ1_pulse = '0' report "BTHOLD suppresses both equality pulses" severity failure;
        assert pwmout = '0' report "BTHOLD preserves output" severity failure;

        -- BTCLR
        write_reg(x"00000000", cs_btctl1, x"00000024"); -- BTCLR=1 while held
        wait for 1 ns;
        assert uut_btcnt = x"00000000" report "BTCLR clears BTCNT" severity failure;
        assert uut_equ0_pulse = '0' and uut_equ1_pulse = '0' report "BTCLR suppresses equality pulses" severity failure;
        assert pwmout = '0' report "BTCLR retains PWM" severity failure;

        -- Test 5: BTCMPR writing and zero checks
        write_reg(x"00000000", cs_btctl1, x"00000004"); -- clear BTHOLD, BTCLR=1
        write_reg(x"00000000", cs_btcmpr0, x"0000000F");
        wait for 1 ns;
        assert pwmout = '0' report "BTCMPR write does not directly change output" severity failure;

        -- Test BTCL0=0 and BTCL1=0 per-cycle transient monitoring (10 edges)
        write_reg(x"00000000", cs_btcmpr0, x"00000000");
        write_reg(x"00000000", cs_btcmpr1, x"00000000");
        write_reg(x"00000000", cs_btctl1, x"00000004"); -- BTCLR=1
        for i in 1 to 10 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_equ0_pulse = '0' report "BTCL0=0 cannot change PWM through EQU0" severity failure;
            assert uut_equ1_pulse = '0' report "BTCL1=0 cannot change PWM through EQU1" severity failure;
            assert pwmout = '0' report "BTCL=0 preserves PWM output" severity failure;
        end loop;

        -- Section 3 & 4: Exact Capture plus Timer-Tick Test
        write_reg(x"00000000", cs_btcmpr0, x"00000100"); -- BTCL0 = 0x100
        write_reg(x"00000000", cs_btcmpr1, x"00000200"); -- BTCL1 = 0x200
        write_reg(x"00000000", cs_btctl1, x"00000004");  -- BTHOLD=0, BTSSEL=00, BTCLR=1
        write_reg(x"00000000", cs_btctl1, x"00000000");  -- BTCLR=0
        write_reg(x"00000000", cs_btctl2, x"00000004");  -- CAPMD=01 (rising), CAPISEL=00 (CAPIN1)

        capin1 <= '0';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        wait until falling_edge(clk);
        capin1 <= '1';

        -- Edge A check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capin1_sync_stage1 = '1' report "Edge A: stage1 equals new level" severity failure;
        assert uut_capin1_sync_stage2 = '0' report "Edge A: stage2 equals old level" severity failure;
        assert uut_capture_pulse = '0' report "Edge A: capture_pulse is 0" severity failure;

        -- Edge B check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capin1_sync_stage2 = '1' report "Edge B: stage2 equals new level" severity failure;
        assert uut_capture_pulse = '0' report "Edge B: capture_pulse is 0" severity failure;

        -- Falling half-cycle immediately before Edge C
        wait until falling_edge(clk);
        expected_pre_cnt := uut_btcnt;

        -- Edge C check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '1' report "Edge C: capture_pulse is 1" severity failure;
        assert btcapr = expected_pre_cnt report "Edge C: btcapr equals expected pre-edge BTCNT" severity failure;
        assert uut_btcnt = std_logic_vector(unsigned(expected_pre_cnt) + 1) report "Edge C: uut_btcnt equals expected_pre_cnt + 1" severity failure;

        -- Following MCLK edge check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '0' report "Following edge: capture_pulse is 0" severity failure;
        assert btcapr = expected_pre_cnt report "Following edge: btcapr remains expected_pre_cnt" severity failure;

        -- Stable-input duplicate protection (3 consecutive edges)
        for i in 1 to 3 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "Stable input: capture_pulse is 0" severity failure;
            assert btcapr = expected_pre_cnt report "Stable input: btcapr remains unchanged" severity failure;
        end loop;

        -- Section 5: Exact Capture plus BTCLR Test
        write_reg(x"00000000", cs_btctl2, x"00000004"); -- CAPMD=01, CAPISEL=00
        capin1 <= '0';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        wait until falling_edge(clk);
        capin1 <= '1';

        -- Edge A check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capin1_sync_stage1 = '1' report "BTCLR Edge A: stage1 equals new level" severity failure;
        assert uut_capin1_sync_stage2 = '0' report "BTCLR Edge A: stage2 equals old level" severity failure;
        assert uut_capture_pulse = '0' report "BTCLR Edge A: capture_pulse is 0" severity failure;

        -- Edge B check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capin1_sync_stage2 = '1' report "BTCLR Edge B: stage2 equals new level" severity failure;
        assert uut_capture_pulse = '0' report "BTCLR Edge B: capture_pulse is 0" severity failure;

        -- Falling half-cycle immediately before Edge C
        wait until falling_edge(clk);
        expected_pre_cnt := uut_btcnt;
        cs_btctl1 <= '1';
        wdata <= x"00000004"; -- BTCLR=1, BTHOLD=0, BTSSEL=00, BTINT=00
        mmio_write <= '1';
        wait for 1 ns;
        assert mmio_write = '1' and cs_btctl1 = '1' report "BTCLR write controls asserted before Edge C" severity failure;

        -- Edge C check (Simultaneous Capture & BTCLR)
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '1' report "BTCLR Edge C: capture_pulse is 1" severity failure;
        assert btcapr = expected_pre_cnt report "BTCLR Edge C: btcapr equals expected pre-edge BTCNT" severity failure;
        assert uut_btcnt = x"00000000" report "BTCLR Edge C: uut_btcnt is 0" severity failure;
        assert uut_equ0_pulse = '0' report "BTCLR Edge C: equ0_pulse is 0" severity failure;
        assert uut_equ1_pulse = '0' report "BTCLR Edge C: equ1_pulse is 0" severity failure;

        -- Deassert write controls
        cs_btctl1 <= '0';
        mmio_write <= '0';

        -- Following MCLK edge check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '0' report "BTCLR Following edge: capture_pulse is 0" severity failure;
        assert btcapr = expected_pre_cnt report "BTCLR Following edge: btcapr remains expected_pre_cnt" severity failure;

        -- Section 6: Configuration-Write Windows
        capin1 <= '1';
        capin2 <= '0';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;

        -- Op 1: BTCTL2 write
        wait until falling_edge(clk);
        saved_capr := btcapr;
        cs_btctl2 <= '1'; wdata <= x"00000004"; mmio_write <= '1';
        wait until rising_edge(clk); wait for 1 ns; -- Write edge
        assert uut_capture_pulse = '0' report "Op1 write edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op1 write edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op1 write edge BTCAPR unchanged" severity failure;
        wait until falling_edge(clk);
        cs_btctl2 <= '0'; mmio_write <= '0';
        wait until rising_edge(clk); wait for 1 ns; -- Following edge
        assert uut_capture_pulse = '0' report "Op1 following edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op1 following edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op1 following edge BTCAPR unchanged" severity failure;

        -- Op 2: CAPISEL change (00 -> 01 CAPIN2)
        wait until falling_edge(clk);
        saved_capr := btcapr;
        cs_btctl2 <= '1'; wdata <= x"00000005"; mmio_write <= '1'; -- CAPMD=01, CAPISEL=01
        wait until rising_edge(clk); wait for 1 ns; -- Write edge
        assert uut_capture_pulse = '0' report "Op2 write edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op2 write edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op2 write edge BTCAPR unchanged" severity failure;
        assert uut_previous_capture_level = uut_capin2_sync_stage2 report "Op2 write edge previous_capture_level equals CAPIN2 sync level" severity failure;
        wait until falling_edge(clk);
        cs_btctl2 <= '0'; mmio_write <= '0';
        wait until rising_edge(clk); wait for 1 ns; -- Following edge
        assert uut_capture_pulse = '0' report "Op2 following edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op2 following edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op2 following edge BTCAPR unchanged" severity failure;

        -- Op 3: CAPMD change (01 -> 10)
        wait until falling_edge(clk);
        saved_capr := btcapr;
        cs_btctl2 <= '1'; wdata <= x"00000009"; mmio_write <= '1'; -- CAPMD=10, CAPISEL=01
        wait until rising_edge(clk); wait for 1 ns; -- Write edge
        assert uut_capture_pulse = '0' report "Op3 write edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op3 write edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op3 write edge BTCAPR unchanged" severity failure;
        wait until falling_edge(clk);
        cs_btctl2 <= '0'; mmio_write <= '0';
        wait until rising_edge(clk); wait for 1 ns; -- Following edge
        assert uut_capture_pulse = '0' report "Op3 following edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op3 following edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op3 following edge BTCAPR unchanged" severity failure;

        -- Op 4: CAPISEL constant 1 (CAPISEL=10)
        wait until falling_edge(clk);
        saved_capr := btcapr;
        cs_btctl2 <= '1'; wdata <= x"00000006"; mmio_write <= '1'; -- CAPMD=01, CAPISEL=10
        wait until rising_edge(clk); wait for 1 ns; -- Write edge
        assert uut_capture_pulse = '1' report "Op4 GND-to-VCC selector change creates rising capture" severity failure;
        assert btcapr /= saved_capr report "Op4 selector capture updates BTCAPR" severity failure;
        assert uut_previous_capture_level = '1' report "Op4 write edge previous_capture_level = 1" severity failure;
        saved_capr := btcapr;
        wait until falling_edge(clk);
        cs_btctl2 <= '0'; mmio_write <= '0';
        wait until rising_edge(clk); wait for 1 ns; -- Following edge
        assert uut_capture_pulse = '0' report "Op4 following edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op4 following edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op4 following edge BTCAPR unchanged" severity failure;

        -- CAPISEL=10 per-cycle transient monitoring (5 complete edges)
        for i in 1 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPISEL=10 per-cycle capture_pulse = 0" severity failure;
            assert timer_event = '0' report "CAPISEL=10 per-cycle timer_event = 0" severity failure;
            assert btcapr = saved_capr report "CAPISEL=10 per-cycle BTCAPR unchanged" severity failure;
        end loop;

        -- Op 5: CAPISEL constant 0 (CAPISEL=11)
        wait until falling_edge(clk);
        saved_capr := btcapr;
        cs_btctl2 <= '1'; wdata <= x"00000007"; mmio_write <= '1'; -- CAPMD=01, CAPISEL=11
        wait until rising_edge(clk); wait for 1 ns; -- Write edge
        assert uut_capture_pulse = '0' report "Op5 write edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op5 write edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op5 write edge BTCAPR unchanged" severity failure;
        assert uut_previous_capture_level = '0' report "Op5 write edge previous_capture_level = 0" severity failure;
        wait until falling_edge(clk);
        cs_btctl2 <= '0'; mmio_write <= '0';
        wait until rising_edge(clk); wait for 1 ns; -- Following edge
        assert uut_capture_pulse = '0' report "Op5 following edge capture_pulse = 0" severity failure;
        assert timer_event = '0' report "Op5 following edge timer_event = 0" severity failure;
        assert btcapr = saved_capr report "Op5 following edge BTCAPR unchanged" severity failure;

        -- CAPISEL=11 per-cycle transient monitoring (5 complete edges)
        for i in 1 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPISEL=11 per-cycle capture_pulse = 0" severity failure;
            assert timer_event = '0' report "CAPISEL=11 per-cycle timer_event = 0" severity failure;
            assert btcapr = saved_capr report "CAPISEL=11 per-cycle BTCAPR unchanged" severity failure;
        end loop;

        -- Section 7: CAPMD=00 and CAPMD=11 Transient Monitoring (5 complete edges each)
        saved_capr := btcapr;
        write_reg(x"00000000", cs_btctl2, x"00000000"); -- CAPMD=00
        capin1 <= '1';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPMD=00 per-cycle capture_pulse = 0" severity failure;
            assert btcapr = saved_capr report "CAPMD=00 per-cycle BTCAPR unchanged" severity failure;
        end loop;

        saved_capr := btcapr;
        write_reg(x"00000000", cs_btctl2, x"0000000C"); -- CAPMD=11
        capin1 <= '1';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPMD=11 per-cycle capture_pulse = 0" severity failure;
            assert btcapr = saved_capr report "CAPMD=11 per-cycle BTCAPR unchanged" severity failure;
        end loop;

        -- Section 8: Repeated Capture and Interrupt Width
        write_reg(x"00000000", cs_btctl2, x"00000004"); -- CAPMD=01, CAPISEL=00
        -- First valid capture
        capin1 <= '0';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        wait until falling_edge(clk);
        capin1 <= '1';
        wait until rising_edge(clk); -- Edge A
        wait until rising_edge(clk); -- Edge B
        wait until falling_edge(clk);
        expected_cnt1 := uut_btcnt;
        wait until rising_edge(clk); wait for 1 ns; -- Edge C
        assert uut_capture_pulse = '1' report "First capture pulse = 1" severity failure;
        assert btcapr = expected_cnt1 report "First capture btcapr = expected_cnt1" severity failure;

        -- Second valid capture
        capin1 <= '0';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        wait until falling_edge(clk);
        capin1 <= '1';
        wait until rising_edge(clk); -- Edge A
        wait until rising_edge(clk); -- Edge B
        wait until falling_edge(clk);
        expected_cnt2 := uut_btcnt;
        wait until rising_edge(clk); wait for 1 ns; -- Edge C
        assert uut_capture_pulse = '1' report "Second capture pulse = 1" severity failure;
        assert btcapr = expected_cnt2 report "Second capture btcapr = expected_cnt2" severity failure;
        assert expected_cnt1 /= expected_cnt2 report "First and second expected capture counts differ" severity failure;

        -- BTINT=00 (EQU0) Interrupt Width
        write_reg(x"00000000", cs_btcmpr0, x"00000008");
        write_reg(x"00000000", cs_btctl1, x"00000004"); -- BTINT=00, BTCLR=1
        wait_pulse(timer_event, 20, "BTINT=00 creates one timer_event_o pulse on EQU0");
        assert timer_event = '1' report "BTINT=00 timer_event = 1" severity failure;
        wait until rising_edge(clk); wait for 1 ns;
        assert timer_event = '0' report "BTINT=00 timer_event = 0 on following edge" severity failure;

        -- BTINT=01 (EQU1) Interrupt Width
        write_reg(x"00000000", cs_btcmpr1, x"00000008");
        write_reg(x"00000000", cs_btctl1, x"00000005"); -- BTINT=01, BTCLR=1
        wait_pulse(timer_event, 20, "BTINT=01 creates one timer_event_o pulse on EQU1");
        assert timer_event = '1' report "BTINT=01 timer_event = 1" severity failure;
        wait until rising_edge(clk); wait for 1 ns;
        assert timer_event = '0' report "BTINT=01 timer_event = 0 on following edge" severity failure;

        -- BTINT=10 (Capture) Interrupt Width
        write_reg(x"00000000", cs_btctl2, x"00000004"); -- CAPMD=01, CAPISEL=00
        write_reg(x"00000000", cs_btctl1, x"00000006"); -- BTINT=10, BTCLR=1
        capin1 <= '0'; for i in 1 to 5 loop wait until rising_edge(clk); end loop;
        capin1 <= '1';
        wait_pulse(timer_event, 20, "BTINT=10 produces one-cycle timer event");
        assert timer_event = '1' report "BTINT=10 timer_event = 1" severity failure;
        wait until rising_edge(clk); wait for 1 ns;
        assert timer_event = '0' report "BTINT=10 timer_event = 0 on following edge" severity failure;

        -- BTINT=11 (Disabled) Interrupt
        write_reg(x"00000000", cs_btctl1, x"00000007"); -- BTINT=11, BTCLR=1
        capin1 <= '0'; for i in 1 to 5 loop wait until rising_edge(clk); end loop;
        wait until falling_edge(clk);
        capin1 <= '1';
        wait until rising_edge(clk); -- Edge A
        wait until rising_edge(clk); -- Edge B
        wait until falling_edge(clk);
        expected_pre_cnt := uut_btcnt;
        wait until rising_edge(clk); wait for 1 ns; -- Edge C
        assert uut_capture_pulse = '1' report "BTINT=11 real capture_pulse = 1" severity failure;
        assert btcapr = expected_pre_cnt report "BTINT=11 btcapr updates to pre-edge BTCNT" severity failure;
        assert timer_event = '0' report "BTINT=11 timer_event = 0 on capture edge" severity failure;
        wait until rising_edge(clk); wait for 1 ns; -- Following edge
        assert timer_event = '0' report "BTINT=11 timer_event = 0 on following edge" severity failure;

        -- Additional Recovery Tests: Real CAPMD=10 Falling Capture
        write_reg(x"00000000", cs_btctl2, x"00000008"); -- CAPMD=10 (falling), CAPISEL=00 (CAPIN1)
        capin1 <= '1';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        wait until falling_edge(clk);
        capin1 <= '0';

        -- Edge A check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capin1_sync_stage1 = '0' report "Falling Edge A: stage1 equals 0" severity failure;
        assert uut_capin1_sync_stage2 = '1' report "Falling Edge A: stage2 equals 1" severity failure;
        assert uut_capture_pulse = '0' report "Falling Edge A: capture_pulse is 0" severity failure;

        -- Edge B check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capin1_sync_stage2 = '0' report "Falling Edge B: stage2 equals 0" severity failure;
        assert uut_capture_pulse = '0' report "Falling Edge B: capture_pulse is 0" severity failure;

        -- Immediately before Edge C
        wait until falling_edge(clk);
        expected_falling_cnt := uut_btcnt;

        -- Edge C check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '1' report "Falling Edge C: capture_pulse is 1" severity failure;
        assert btcapr = expected_falling_cnt report "Falling Edge C: btcapr equals expected_falling_cnt" severity failure;

        -- Following MCLK edge check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '0' report "Falling Following edge: capture_pulse is 0" severity failure;
        assert btcapr = expected_falling_cnt report "Falling Following edge: btcapr remains expected_falling_cnt" severity failure;

        -- Additional Recovery Tests: Real CAPIN2 Capture & CAPIN1 Ignored
        write_reg(x"00000000", cs_btctl2, x"00000005"); -- CAPMD=01 (rising), CAPISEL=01 (CAPIN2)
        capin1 <= '0';
        capin2 <= '0';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        wait until falling_edge(clk);
        capin2 <= '1';

        -- Edge A check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capin2_sync_stage1 = '1' report "CAPIN2 Edge A: stage1 equals 1" severity failure;
        assert uut_capin2_sync_stage2 = '0' report "CAPIN2 Edge A: stage2 equals 0" severity failure;
        assert uut_capture_pulse = '0' report "CAPIN2 Edge A: capture_pulse is 0" severity failure;

        -- Edge B check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capin2_sync_stage2 = '1' report "CAPIN2 Edge B: stage2 equals 1" severity failure;
        assert uut_capture_pulse = '0' report "CAPIN2 Edge B: capture_pulse is 0" severity failure;

        -- Immediately before Edge C
        wait until falling_edge(clk);
        expected_capin2_cnt := uut_btcnt;

        -- Edge C check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '1' report "CAPIN2 Edge C: capture_pulse is 1" severity failure;
        assert btcapr = expected_capin2_cnt report "CAPIN2 Edge C: btcapr equals expected_capin2_cnt" severity failure;
        assert uut_capin2_sync_stage2 = '1' report "CAPIN2 Edge C: stage2 equals 1" severity failure;

        -- Following MCLK edge check
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '0' report "CAPIN2 Following edge: capture_pulse is 0" severity failure;
        assert btcapr = expected_capin2_cnt report "CAPIN2 Following edge: btcapr remains expected_capin2_cnt" severity failure;

        -- Toggle CAPIN1 while CAPISEL=01 to prove CAPIN1 is ignored
        capin1 <= '1';
        for i in 1 to 3 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPIN1 toggle ignored while CAPISEL=01: capture_pulse is 0" severity failure;
            assert btcapr = expected_capin2_cnt report "CAPIN1 toggle ignored while CAPISEL=01: BTCAPR unchanged" severity failure;
        end loop;

        capin1 <= '0';
        for i in 1 to 3 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPIN1 falling toggle ignored while CAPISEL=01: capture_pulse is 0" severity failure;
            assert btcapr = expected_capin2_cnt report "CAPIN1 falling toggle ignored while CAPISEL=01: BTCAPR unchanged" severity failure;
        end loop;

        -- Additional Recovery Tests: BTCLR without Capture preserving BTCAPR
        saved_capr := btcapr;
        wait until falling_edge(clk);
        cs_btctl1 <= '1';
        wdata <= x"00000004"; -- BTCLR=1
        mmio_write <= '1';
        wait for 1 ns;
        assert mmio_write = '1' and cs_btctl1 = '1' report "BTCLR without capture write controls asserted" severity failure;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '0' report "BTCLR without capture: capture_pulse = 0" severity failure;
        assert btcapr = saved_capr report "BTCLR without capture: BTCAPR preserved" severity failure;
        assert uut_btcnt = x"00000000" report "BTCLR without capture: BTCNT = 0" severity failure;
        assert uut_equ0_pulse = '0' report "BTCLR without capture: EQU0 pulse = 0" severity failure;
        assert uut_equ1_pulse = '0' report "BTCLR without capture: EQU1 pulse = 0" severity failure;

        cs_btctl1 <= '0';
        mmio_write <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;
        assert uut_capture_pulse = '0' report "BTCLR without capture following edge: capture_pulse = 0" severity failure;
        assert btcapr = saved_capr report "BTCLR without capture following edge: BTCAPR preserved" severity failure;

        -- Additional Recovery Tests: Repaired CAPMD=00 real transition rejection (rising and falling)
        write_reg(x"00000000", cs_btctl1, x"00000006"); -- BTINT=10 (Capture Interrupt)
        write_reg(x"00000000", cs_btctl2, x"00000000"); -- CAPMD=00, CAPISEL=00
        capin1 <= '0';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        saved_capr := btcapr;

        -- Real rising transition on CAPIN1
        wait until falling_edge(clk);
        capin1 <= '1';

        for i in 1 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPMD=00 rising transition capture_pulse = 0" severity failure;
            assert timer_event = '0' report "CAPMD=00 rising transition timer_event_o = 0" severity failure;
            assert btcapr = saved_capr report "CAPMD=00 rising transition BTCAPR unchanged" severity failure;
        end loop;

        -- Real falling transition on CAPIN1
        wait until falling_edge(clk);
        capin1 <= '0';

        for i in 1 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPMD=00 falling transition capture_pulse = 0" severity failure;
            assert timer_event = '0' report "CAPMD=00 falling transition timer_event_o = 0" severity failure;
            assert btcapr = saved_capr report "CAPMD=00 falling transition BTCAPR unchanged" severity failure;
        end loop;

        -- Additional Recovery Tests: Repaired CAPMD=11 real transition rejection (rising and falling)
        write_reg(x"00000000", cs_btctl1, x"00000006"); -- BTINT=10 (Capture Interrupt)
        write_reg(x"00000000", cs_btctl2, x"0000000C"); -- CAPMD=11, CAPISEL=00
        capin1 <= '0';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        saved_capr := btcapr;

        -- Real rising transition on CAPIN1
        wait until falling_edge(clk);
        capin1 <= '1';

        for i in 1 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPMD=11 rising transition capture_pulse = 0" severity failure;
            assert timer_event = '0' report "CAPMD=11 rising transition timer_event_o = 0" severity failure;
            assert btcapr = saved_capr report "CAPMD=11 rising transition BTCAPR unchanged" severity failure;
        end loop;

        -- Real falling transition on CAPIN1
        wait until falling_edge(clk);
        capin1 <= '0';

        for i in 1 to 5 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert uut_capture_pulse = '0' report "CAPMD=11 falling transition capture_pulse = 0" severity failure;
            assert timer_event = '0' report "CAPMD=11 falling transition timer_event_o = 0" severity failure;
            assert btcapr = saved_capr report "CAPMD=11 falling transition BTCAPR unchanged" severity failure;
        end loop;

        -- Section 9: Real Old-BTCL Bounded Wait Test
        -- 1. Hold timer
        write_reg(x"00000000", cs_btctl1, x"00000020"); -- BTHOLD=1
        -- 2. Program old BTCL0=10, BTCL1=20
        write_reg(x"00000000", cs_btcmpr0, std_logic_vector(to_unsigned(10, 32)));
        write_reg(x"00000000", cs_btcmpr1, std_logic_vector(to_unsigned(20, 32)));
        -- 3. Clear BTCNT while held
        write_reg(x"00000000", cs_btctl1, x"00000024"); -- BTHOLD=1, BTCLR=1
        -- 4. Release hold
        write_reg(x"00000000", cs_btctl1, x"00000000"); -- BTOUTEN=0, BTHOLD=0, BTCLR=0

        -- 5. Bounded loop (max 32 cycles) waiting for BTCNT=5
        found_flag := false;
        for i in 1 to 32 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if uut_btcnt = std_logic_vector(to_unsigned(5, 32)) then
                found_flag := true;
                exit;
            end if;
        end loop;
        assert found_flag report "bounded wait for BTCNT=5 target failed" severity failure;

        -- 6. During falling half-cycle before next MCLK rising edge (when BTCNT is 5), write BTCL0 = 15
        wait until falling_edge(clk);
        cs_btcmpr0 <= '1';
        mmio_write <= '1';
        wdata <= std_logic_vector(to_unsigned(15, 32));

        -- 7 & 8. At following rising edge, check old state before delta settling and after delta settling
        wait until rising_edge(clk);
        cs_btcmpr0 <= '0';
        mmio_write <= '0';
        wait for 1 ns; -- Settling
        assert uut_equ0_pulse = '0' report "old BTCL collision: equ0_pulse = 0" severity failure;
        assert uut_btcnt = std_logic_vector(to_unsigned(6, 32)) report "old BTCL collision: btcnt followed normal non-match update to 6" severity failure;
        assert btcmpr0 = std_logic_vector(to_unsigned(15, 32)) report "old BTCL collision: btcmpr0 output = 15" severity failure;
        assert uut_btcl0 = std_logic_vector(to_unsigned(15, 32)) report "old BTCL collision: internal btcl0 = 15" severity failure;
        assert pwmout = '0' report "old BTCL collision: no EQU0-driven PWM action occurred" severity failure;

        -- 9. Bounded wait (max 32 cycles) to prove newly stored BTCL0=15 later generates actual EQU0 pulse
        found_flag := false;
        for i in 1 to 32 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if uut_equ0_pulse = '1' then
                found_flag := true;
                exit;
            end if;
        end loop;
        assert found_flag report "new BTCL0=15 EQU0 pulse timeout" severity failure;
        assert pwmout = '1' report "newly stored BTCL0=15 generates actual EQU0 pulse and PWM set" severity failure;

        report "PASS: tb_basic_timer_phase8b";
        std.env.finish(0);
    end process;
end sim;
