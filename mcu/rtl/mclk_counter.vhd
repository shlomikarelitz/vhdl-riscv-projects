library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity mclk_counter is
    generic (
        CLK_CNT_WIDTH : integer := 16
    );
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        mclk_cnt_o : out std_logic_vector(CLK_CNT_WIDTH-1 downto 0)
    );
end mclk_counter;

architecture rtl of mclk_counter is
    signal mclk_cnt_q : std_logic_vector(CLK_CNT_WIDTH-1 downto 0);
begin

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            mclk_cnt_q <= (others => '0');
        elsif rising_edge(clk_i) then
            mclk_cnt_q <= mclk_cnt_q + 1;
        end if;
    end process;

    mclk_cnt_o <= mclk_cnt_q;

end rtl;
