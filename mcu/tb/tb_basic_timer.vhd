library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_basic_timer is
end tb_basic_timer;

architecture sim of tb_basic_timer is
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

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal mmio_write : std_logic := '0';
    signal wdata : std_logic_vector(31 downto 0) := (others => '0');
    signal cs_btctl1 : std_logic := '0';
    signal cs_btctl2 : std_logic := '0';
    signal cs_btcmpr0 : std_logic := '0';
    signal cs_btcmpr1 : std_logic := '0';
    
    signal btctl1_o : std_logic_vector(7 downto 0);
    signal btctl2_o : std_logic_vector(7 downto 0);
    signal btcmpr0_o : std_logic_vector(31 downto 0);
    signal btcmpr1_o : std_logic_vector(31 downto 0);
    signal btcapr_o : std_logic_vector(31 downto 0);
    signal timer_event : std_logic;

    constant CLK_PERIOD : time := 10 ns;
begin

    UUT: basic_timer port map (
        clk_i => clk,
        rst_i => rst,
        mmio_write_i => mmio_write,
        wdata_i => wdata,
        cs_btctl1_i => cs_btctl1,
        cs_btctl2_i => cs_btctl2,
        cs_btcmpr0_i => cs_btcmpr0,
        cs_btcmpr1_i => cs_btcmpr1,
        capin1_i => '0',
        capin2_i => '0',
        pwmout_o => open,
        btctl1_o => btctl1_o,
        btctl2_o => btctl2_o,
        btcmpr0_o => btcmpr0_o,
        btcmpr1_o => btcmpr1_o,
        btcapr_o => btcapr_o,
        timer_event_o => timer_event
    );

    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    stim_process: process
        alias mclk_prescaler is << signal UUT.prescaler : unsigned(2 downto 0) >>;
        alias btcnt is << signal UUT.btcnt : std_logic_vector(31 downto 0) >>;
        alias btcl0 is << signal UUT.btcl0 : std_logic_vector(31 downto 0) >>;
        alias equ0_pulse is << signal UUT.equ0_pulse : std_logic >>;
        alias equ1_pulse is << signal UUT.equ1_pulse : std_logic >>;

        procedure write_reg(addr : string; data : std_logic_vector) is
        begin
            wait until rising_edge(clk);
            mmio_write <= '1';
            wdata <= data;
            if addr = "BTCTL1" then cs_btctl1 <= '1';
            elsif addr = "BTCTL2" then cs_btctl2 <= '1';
            elsif addr = "BTCMPR0" then cs_btcmpr0 <= '1';
            elsif addr = "BTCMPR1" then cs_btcmpr1 <= '1';
            end if;
            wait until rising_edge(clk);
            mmio_write <= '0';
            cs_btctl1 <= '0';
            cs_btctl2 <= '0';
            cs_btcmpr0 <= '0';
            cs_btcmpr1 <= '0';
        end procedure;

        variable event_count : integer := 0;
        variable old_pre : unsigned(2 downto 0) := (others => '0');
        variable cap_btcnt : std_logic_vector(31 downto 0);
    begin
        rst <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        rst <= '0';
        
        -- Reset assertions
        assert btctl1_o = x"00" report "reset BTCTL1 readback != 0x00" severity failure;
        assert btctl2_o = x"00" report "reset BTCTL2 readback != 0x00" severity failure;
        assert btcmpr0_o = x"00000000" report "reset BTCMPR0 != zero" severity failure;
        assert btcmpr1_o = x"00000000" report "reset BTCMPR1 != zero" severity failure;
        assert btcapr_o = x"00000000" report "reset BTCAPR != zero" severity failure;
        
        -- deterministic post-reset zero-compare behavior
        -- Timer ticks every cycle. BTCNT=0, BTCL0=0.
        -- Since BTCL0=0, timer_event should be 0 because a period of 0 is invalid.
        wait for CLK_PERIOD * 3;
        assert timer_event = '0' report "post-reset zero-compare behavior failed" severity failure;
        wait until rising_edge(clk);
        
        -- Write BTCTL1 with BTHOLD=1 to stop it, BTOUTMD=1, BTOUTEN=1
        write_reg("BTCTL1", x"000000E0"); -- 1110 0000 (BTOUTMD, BTOUTEN, BTHOLD)
        wait for CLK_PERIOD;
        assert btctl1_o = x"E0" report "stored BTOUTMD/BTOUTEN/BTHOLD readback failed" severity failure;
        
        -- BTHOLD prevents all equality pulses
        wait for CLK_PERIOD * 2;
        assert timer_event = '0' report "BTHOLD prevents equality failed" severity failure;
        
        -- BTCLR while BTHOLD=1
        write_reg("BTCTL1", x"000000E4"); -- set BTCLR bit 2
        wait for CLK_PERIOD;
        assert btctl1_o = x"E0" report "BTCLR always reads zero failed" severity failure;
        
        -- Write BTCTL2 CAPMD=11, CAPISEL=11
        write_reg("BTCTL2", x"000000FF");
        wait for CLK_PERIOD;
        assert btctl2_o = x"0F" report "BTCTL2 upper nibble reads zero failed" severity failure;
        
        -- BTCMPR0 write/read
        write_reg("BTCMPR0", x"0000000A");
        wait for CLK_PERIOD;
        assert btcmpr0_o = x"0000000A" report "BTCMPR0 write/read failed" severity failure;
        
        -- Test Disable
        write_reg("BTCTL1", x"00000020"); -- hold
        wait for CLK_PERIOD * 10;
        assert timer_event = '0' report "timer generated event while hold" severity failure;
        
        -- release hold, BTSSEL=/1 (00)
        write_reg("BTCTL1", x"00000000"); 
        
        wait until rising_edge(clk) and timer_event = '1';
        event_count := 0;
        loop
            wait until rising_edge(clk);
            if timer_event = '1' then 
                exit; 
            end if;
            event_count := event_count + 1;
        end loop;
        assert event_count = 10 report "EQU0 period != BTCL0+1" severity failure;
        
        -- timer_event_o pulse width exactly one MCLK cycle
        wait until rising_edge(clk);
        assert timer_event = '0' report "timer_event_o pulse width > 1 cycle" severity failure;
        
        -- Test explicit BTCMPR0=0 disables EQU0
        write_reg("BTCTL1", x"00000020"); -- hold
        write_reg("BTCMPR0", x"00000005");
        write_reg("BTCTL1", x"00000024"); -- BTCLR
        write_reg("BTCMPR0", x"00000000"); -- set to 0
        write_reg("BTCTL1", x"00000000"); -- unhold, EQU0
        wait for CLK_PERIOD * 10;
        assert timer_event = '0' report "explicit BTCMPR0=0 disables EQU0 failed" severity failure;
        
        -- Test explicit BTCMPR1=0 disables EQU1
        write_reg("BTCTL1", x"00000020"); -- hold
        write_reg("BTCMPR1", x"00000005");
        write_reg("BTCTL1", x"00000024"); -- BTCLR
        write_reg("BTCMPR1", x"00000000"); -- set to 0
        write_reg("BTCTL1", x"00000001"); -- unhold, EQU1
        wait for CLK_PERIOD * 10;
        assert timer_event = '0' report "explicit BTCMPR1=0 disables EQU1 failed" severity failure;
        
        -- Test simultaneous EQU0/EQU1 wrap (BTCL0=3, BTCL1=3)
        write_reg("BTCTL1", x"00000020"); -- hold
        write_reg("BTCMPR0", x"00000003");
        write_reg("BTCMPR1", x"00000003");
        write_reg("BTCTL1", x"00000024"); -- hold + BTCLR
        write_reg("BTCTL1", x"00000000"); -- unhold
        wait until rising_edge(clk) and timer_event = '1';
        -- if EQU0 wraps, next count is 0, so in 3 cycles it should be 3 again.
        -- Period is 4.
        event_count := 0;
        loop
            wait until rising_edge(clk);
            if timer_event = '1' then exit; end if;
            event_count := event_count + 1;
        end loop;
        assert event_count = 3 report "simultaneous EQU0 wrap failed" severity failure;
        
        -- BTINT selects
        write_reg("BTCTL1", x"00000001"); -- BTINT = 01 (EQU1)
        wait until rising_edge(clk) and timer_event = '1';
        write_reg("BTCTL1", x"00000002"); -- BTINT = 10
        event_count := 0;
        wait until rising_edge(clk);
        while event_count < 20 loop
            assert timer_event = '0' report "BTINT=10 produced event" severity failure;
            event_count := event_count + 1;
            wait until rising_edge(clk);
        end loop;
        
        write_reg("BTCTL1", x"00000003"); -- BTINT = 11
        event_count := 0;
        while event_count < 20 loop
            assert timer_event = '0' report "BTINT=11 produced event" severity failure;
            event_count := event_count + 1;
            wait until rising_edge(clk);
        end loop;
        
        -- BTSSEL spacing
        -- Test BTSSEL /2
        write_reg("BTCMPR0", x"00000001"); -- period = 2 ticks = 4 cycles
        write_reg("BTCTL1", x"0000000C"); -- BTCLR + /2 + EQU0
        write_reg("BTCTL1", x"00000008"); -- /2 + EQU0
        wait until rising_edge(clk) and timer_event = '1';
        event_count := 0;
        loop
            wait until rising_edge(clk);
            if timer_event = '1' then exit; end if;
            event_count := event_count + 1;
        end loop;
        assert event_count = 3 report "BTSSEL /2 spacing failed" severity failure;
        
        -- Test BTSSEL /4
        write_reg("BTCMPR0", x"00000001");
        write_reg("BTCTL1", x"00000014"); -- BTCLR + /4 + EQU0
        write_reg("BTCTL1", x"00000010"); -- /4 + EQU0
        wait until rising_edge(clk) and timer_event = '1';
        event_count := 0;
        loop
            wait until rising_edge(clk);
            if timer_event = '1' then exit; end if;
            event_count := event_count + 1;
        end loop;
        assert event_count = 7 report "BTSSEL /4 spacing failed" severity failure;
        
        -- Test BTSSEL /8
        write_reg("BTCMPR0", x"00000001");
        write_reg("BTCTL1", x"0000001C"); -- BTCLR + /8 + EQU0
        write_reg("BTCTL1", x"00000018"); -- /8 + EQU0
        wait until rising_edge(clk) and timer_event = '1';
        event_count := 0;
        loop
            wait until rising_edge(clk);
            if timer_event = '1' then exit; end if;
            event_count := event_count + 1;
        end loop;
        assert event_count = 15 report "BTSSEL /8 spacing failed" severity failure;
        

        -- A. BTCMPR1 readback
        write_reg("BTCMPR1", x"0000CAFE");
        wait for CLK_PERIOD;
        assert btcmpr1_o = x"0000CAFE" report "BTCMPR1 write/read failed" severity failure;

        -- B. BTHOLD counter behavior
        write_reg("BTCTL1", x"00000024"); -- hold + clear
        write_reg("BTCTL1", x"00000020"); -- hold
        wait until rising_edge(clk);
        cap_btcnt := btcnt;
        wait for CLK_PERIOD * 5;
        assert btcnt = cap_btcnt report "BTHOLD counter advanced" severity failure;
        assert timer_event = '0' report "BTHOLD produced event" severity failure;

        -- C. Prescaler while held
        wait until rising_edge(clk);
        old_pre := mclk_prescaler;
        wait for CLK_PERIOD * 3;
        assert mclk_prescaler = (old_pre + 3) mod 8 report "Prescaler while held failed" severity failure;

        -- D. BTCLR and prescaler
        write_reg("BTCTL1", x"00000000"); -- unhold
        wait for CLK_PERIOD * 10;
        wait until rising_edge(clk);
        old_pre := mclk_prescaler;
        write_reg("BTCTL1", x"00000004"); -- BTCLR
        wait for CLK_PERIOD;
        assert btcnt = x"00000000" report "BTCLR failed to clear BTCNT" severity failure;
        assert mclk_prescaler /= 0 report "BTCLR reset the prescaler" severity failure;

        -- E. Compare-before-increment
        write_reg("BTCTL1", x"00000020"); -- hold
        write_reg("BTCMPR0", x"00000004");
        write_reg("BTCTL1", x"00000024"); -- hold + BTCLR
        write_reg("BTCTL1", x"00000000"); -- unhold
        wait until btcnt = x"00000004" and rising_edge(clk);
        wait for 1 ns;
        assert btcnt = x"00000000" report "Compare-before-increment failed: BTCNT did not wrap to 0" severity failure;
        assert timer_event = '1' report "Compare-before-increment failed: event when BTCNT was not BTCL0" severity failure;

        -- F. Old-BTCL write-edge behavior
        write_reg("BTCTL1", x"00000020"); -- hold
        write_reg("BTCMPR0", x"0000000A"); -- old BTCL0
        write_reg("BTCTL1", x"00000024"); -- BTCLR
        write_reg("BTCTL1", x"00000000"); -- unhold
        
        wait until btcnt = x"00000004" and rising_edge(clk);
        -- Setup write so it evaluates on the edge where BTCNT is 5
        mmio_write <= '1';
        cs_btcmpr0 <= '1';
        wdata <= x"00000005";
        wait until rising_edge(clk); 
        -- On this edge, BTCNT becomes 5, but old BTCL0 is 0xA. The write to BTCMPR0 also happens now.
        wait for 1 ns;
        mmio_write <= '0';
        cs_btcmpr0 <= '0';
        assert timer_event = '0' report "Old-BTCL write-edge behavior failed" severity failure;

        -- G. Simultaneous match
        write_reg("BTCTL1", x"00000020"); -- hold
        write_reg("BTCMPR0", x"00000006");
        write_reg("BTCMPR1", x"00000006");
        write_reg("BTCTL1", x"00000024"); -- hold + BTCLR
        write_reg("BTCTL1", x"00000001"); -- unhold, BTINT = 01 (EQU1)
        wait until rising_edge(clk) and equ0_pulse = '1';
        assert equ1_pulse = '1' report "Simultaneous match: equ1_pulse not asserted" severity failure;
        assert timer_event = '1' report "Simultaneous match: timer_event not asserted" severity failure;
        
        -- verify timer_event follows BTINT (change to EQU0)
        write_reg("BTCTL1", x"00000020"); -- hold
        write_reg("BTCTL1", x"00000024"); -- hold + BTCLR
        write_reg("BTCTL1", x"00000000"); -- unhold, BTINT = 00 (EQU0)
        wait until rising_edge(clk) and equ1_pulse = '1';
        assert equ0_pulse = '1' report "Simultaneous match 2: equ0_pulse not asserted" severity failure;
        assert timer_event = '1' report "Simultaneous match 2: timer_event not asserted for EQU0" severity failure;

        report "PASS: tb_basic_timer" severity note;
        std.env.finish;
    end process;

    timeout_proc: process
    begin
        wait for 200 us;
        report "Timeout!" severity failure;
    end process;
end sim;
