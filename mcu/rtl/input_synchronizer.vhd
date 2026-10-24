library ieee;
use ieee.std_logic_1164.all;

entity input_synchronizer is
    generic (
        WIDTH : positive := 3
    );
    port (
        clk_i          : in  std_logic;
        rst_i          : in  std_logic;
        async_i        : in  std_logic_vector(WIDTH-1 downto 0);
        synchronized_o : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity input_synchronizer;

architecture rtl of input_synchronizer is
    -- Two stages of flip-flops for CDC
    signal sync_stage1 : std_logic_vector(WIDTH-1 downto 0);
    signal sync_stage2 : std_logic_vector(WIDTH-1 downto 0);
    
    -- Altera/Intel ASYNC_REG attribute
    attribute altera_attribute : string;
    attribute altera_attribute of sync_stage1 : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS";
    attribute altera_attribute of sync_stage2 : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS";
begin

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            -- Reset to released state (active-low pushbuttons are '1' when released)
            sync_stage1 <= (others => '1');
            sync_stage2 <= (others => '1');
        elsif rising_edge(clk_i) then
            sync_stage1 <= async_i;
            sync_stage2 <= sync_stage1;
        end if;
    end process;

    -- Output only from the second stage
    synchronized_o <= sync_stage2;

end architecture rtl;
