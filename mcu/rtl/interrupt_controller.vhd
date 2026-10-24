library ieee;
use ieee.std_logic_1164.all;

entity interrupt_controller is
    port (
        clk_i             : in  std_logic;
        rst_i             : in  std_logic;       -- active-high internal reset
        event_i           : in  std_logic_vector(6 downto 0);

        mmio_write_i      : in  std_logic;
        cs_ie_i           : in  std_logic;
        cs_ifg_i          : in  std_logic;
        wdata_i           : in  std_logic_vector(7 downto 0);
        
        inta_n_i          : in  std_logic;
        irq_service_pulse_i: in std_logic;
        irq_service_type_i: in  std_logic_vector(7 downto 0);

        ie_rdata_o        : out std_logic_vector(7 downto 0);
        ifg_rdata_o       : out std_logic_vector(7 downto 0);
        type_rdata_o      : out std_logic_vector(7 downto 0);

        irq_pending_raw_o : out std_logic
    );
end entity;

architecture rtl of interrupt_controller is
    -- IE/IFG bits 7:6 are reserved and always read as zero.  The six
    -- implemented sources are UART RX, UART TX, Basic Timer and KEY1..KEY3.
    signal ie_r  : std_logic_vector(5 downto 0);
    signal ifg_r : std_logic_vector(5 downto 0);
    signal enabled_pending_w : std_logic_vector(5 downto 0);
begin
    process(clk_i)
        variable ifg_next : std_logic_vector(5 downto 0);
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ie_r  <= (others => '0');
                ifg_r <= (others => '0');
            else
                if cs_ie_i = '1' and mmio_write_i = '1' then
                    ie_r <= wdata_i(5 downto 0);
                end if;
                
                ifg_next := ifg_r;
                
                if cs_ifg_i = '1' and mmio_write_i = '1' then
                    ifg_next := ifg_next and wdata_i(5 downto 0);
                end if;
                
                if irq_service_pulse_i = '1' then
                    if irq_service_type_i = x"08" then
                        ifg_next(0) := '0';
                    elsif irq_service_type_i = x"0C" then
                        ifg_next(1) := '0';
                    elsif irq_service_type_i = x"10" then
                        ifg_next(2) := '0';
                    end if;
                end if;
                
                -- Hardware event capture wins over a simultaneous software or
                -- service clear, so no pulse can be lost at the boundary.
                ifg_r <= ifg_next or event_i(5 downto 0);
            end if;
        end if;
    end process;

    ie_rdata_o  <= "00" & ie_r;
    ifg_rdata_o <= "00" & ifg_r;

    enabled_pending_w <= ie_r and ifg_r;

    type_rdata_o <= x"08" when enabled_pending_w(0) = '1' else
                    x"0C" when enabled_pending_w(1) = '1' else
                    x"10" when enabled_pending_w(2) = '1' else
                    x"14" when enabled_pending_w(3) = '1' else
                    x"18" when enabled_pending_w(4) = '1' else
                    x"1C" when enabled_pending_w(5) = '1' else
                    x"00";

    irq_pending_raw_o <= '1' when enabled_pending_w /= "000000" else '0';

end architecture rtl;
