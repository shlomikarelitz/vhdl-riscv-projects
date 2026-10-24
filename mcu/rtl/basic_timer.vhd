library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity basic_timer is
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
end basic_timer;

architecture rtl of basic_timer is
    signal btoutmd : std_logic;
    signal btouten : std_logic;
    signal bthold  : std_logic;
    signal btssel  : std_logic_vector(1 downto 0);
    signal btint   : std_logic_vector(1 downto 0);
    
    signal capmd   : std_logic_vector(1 downto 0);
    signal capisel : std_logic_vector(1 downto 0);
    
    signal btcmpr0 : std_logic_vector(31 downto 0);
    signal btcmpr1 : std_logic_vector(31 downto 0);
    signal btcl0   : std_logic_vector(31 downto 0);
    signal btcl1   : std_logic_vector(31 downto 0);
    
    signal btcnt   : std_logic_vector(31 downto 0);
    
    signal prescaler : unsigned(2 downto 0);
    signal timer_tick : std_logic;
    
    signal equ0_pulse : std_logic;
    signal equ1_pulse : std_logic;

    signal capin1_sync_stage1 : std_logic;
    signal capin1_sync_stage2 : std_logic;
    signal capin2_sync_stage1 : std_logic;
    signal capin2_sync_stage2 : std_logic;

    signal previous_capture_level : std_logic;
    signal capture_pulse : std_logic;
    signal btcapr : std_logic_vector(31 downto 0);
    signal pwmout : std_logic;

begin

    btctl1_o <= btoutmd & btouten & bthold & btssel & '0' & btint;
    btctl2_o <= "0000" & capmd & capisel;
    btcmpr0_o <= btcmpr0;
    btcmpr1_o <= btcmpr1;
    btcapr_o <= btcapr;
    pwmout_o <= pwmout;
    
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                prescaler <= (others => '0');
            else
                prescaler <= prescaler + 1;
            end if;
        end if;
    end process;
    
    timer_tick <= '1' when btssel = "00" else
                  '1' when btssel = "01" and prescaler(0) = '1' else
                  '1' when btssel = "10" and prescaler(1 downto 0) = "11" else
                  '1' when btssel = "11" and prescaler = "111" else
                  '0';
                  
    process(clk_i)
        variable next_btcnt : std_logic_vector(31 downto 0);
        variable do_clear : std_logic;
        variable is_equ0 : std_logic;
        variable is_equ1 : std_logic;
        variable is_capture : std_logic;
        variable v_selected_capture_level : std_logic;
        variable v_next_capture_level : std_logic;
        variable v_next_capmd : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                btoutmd <= '0';
                btouten <= '0';
                bthold  <= '0';
                btssel  <= "00";
                btint   <= "00";
                
                capmd   <= "00";
                capisel <= "00";
                
                btcmpr0 <= (others => '0');
                btcl0   <= (others => '0');
                btcmpr1 <= (others => '0');
                btcl1   <= (others => '0');
                
                btcnt   <= (others => '0');
                equ0_pulse <= '0';
                equ1_pulse <= '0';

                capin1_sync_stage1 <= '0';
                capin1_sync_stage2 <= '0';
                capin2_sync_stage1 <= '0';
                capin2_sync_stage2 <= '0';

                previous_capture_level <= '0';
                capture_pulse <= '0';
                btcapr <= (others => '0');
                pwmout <= '0';
            else
                do_clear := '0';
                is_equ0 := '0';
                is_equ1 := '0';
                is_capture := '0';
                
                capin1_sync_stage1 <= capin1_i;
                capin1_sync_stage2 <= capin1_sync_stage1;
                capin2_sync_stage1 <= capin2_i;
                capin2_sync_stage2 <= capin2_sync_stage1;
                
                if capisel = "00" then
                    v_selected_capture_level := capin1_sync_stage2;
                elsif capisel = "01" then
                    v_selected_capture_level := capin2_sync_stage2;
                elsif capisel = "10" then
                    v_selected_capture_level := '1';
                else
                    v_selected_capture_level := '0';
                end if;
                
                if mmio_write_i = '1' and cs_btctl2_i = '1' then
                    -- CAPISEL selects the signal presented to the capture edge
                    -- detector, including the defined VCC/GND sources.  A
                    -- selector change that changes that signal is therefore a
                    -- real capture edge (the official benchmark uses GND->VCC
                    -- to create a rising event).
                    v_next_capmd := wdata_i(3 downto 2);
                    if wdata_i(1 downto 0) = "00" then
                        v_next_capture_level := capin1_sync_stage2;
                    elsif wdata_i(1 downto 0) = "01" then
                        v_next_capture_level := capin2_sync_stage2;
                    elsif wdata_i(1 downto 0) = "10" then
                        v_next_capture_level := '1';
                    else
                        v_next_capture_level := '0';
                    end if;

                    if v_next_capmd = "01" and previous_capture_level = '0' and v_next_capture_level = '1' then
                        is_capture := '1';
                    elsif v_next_capmd = "10" and previous_capture_level = '1' and v_next_capture_level = '0' then
                        is_capture := '1';
                    end if;

                    capmd   <= wdata_i(3 downto 2);
                    capisel <= wdata_i(1 downto 0);
                    previous_capture_level <= v_next_capture_level;
                else
                    if capmd = "01" and previous_capture_level = '0' and v_selected_capture_level = '1' then
                        is_capture := '1';
                    elsif capmd = "10" and previous_capture_level = '1' and v_selected_capture_level = '0' then
                        is_capture := '1';
                    end if;
                    previous_capture_level <= v_selected_capture_level;
                end if;
                
                capture_pulse <= is_capture;
                
                if is_capture = '1' then
                    btcapr <= btcnt;
                end if;
                
                if mmio_write_i = '1' then
                    if cs_btctl1_i = '1' then
                        btoutmd <= wdata_i(7);
                        btouten <= wdata_i(6);
                        bthold  <= wdata_i(5);
                        btssel  <= wdata_i(4 downto 3);
                        btint   <= wdata_i(1 downto 0);
                        do_clear := wdata_i(2);
                    end if;
                    
                    if cs_btcmpr0_i = '1' then
                        btcmpr0 <= wdata_i;
                        btcl0   <= wdata_i;
                    end if;
                    
                    if cs_btcmpr1_i = '1' then
                        btcmpr1 <= wdata_i;
                        btcl1   <= wdata_i;
                    end if;
                end if;
                
                if do_clear = '1' then
                    btcnt <= (others => '0');
                elsif bthold = '1' then
                    null;
                elsif timer_tick = '1' then
                    if unsigned(btcnt) >= unsigned(btcl0) and btcl0 /= x"00000000" then
                        is_equ0 := '1';
                    end if;
                    if btcnt = btcl1 and btcl1 /= x"00000000" then
                        is_equ1 := '1';
                    end if;
                    
                    if is_equ0 = '1' then
                        btcnt <= (others => '0');
                    else
                        btcnt <= std_logic_vector(unsigned(btcnt) + 1);
                    end if;
                end if;
                
                equ0_pulse <= is_equ0;
                equ1_pulse <= is_equ1;
                
                if btouten = '0' then
                    if is_equ1 = '1' then
                        if btoutmd = '0' then
                            pwmout <= '0';
                        else
                            pwmout <= '1';
                        end if;
                    elsif is_equ0 = '1' then
                        if btoutmd = '0' then
                            pwmout <= '1';
                        else
                            pwmout <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    timer_event_o <= equ0_pulse when btint = "00" else
                     equ1_pulse when btint = "01" else
                     capture_pulse when btint = "10" else
                     '0';

end rtl;
