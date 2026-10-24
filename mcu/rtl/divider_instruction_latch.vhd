library ieee;
use ieee.std_logic_1164.all;

-- Transaction-state block used by the structural RV32I core.  The fetched
-- instruction may change while a divide is in flight, so the complete
-- instruction (including rd and funct3) is captured exactly on div_start_i.
entity divider_instruction_latch is
    port (
        clk_i                 : in  std_logic;
        rst_i                 : in  std_logic;
        div_start_i           : in  std_logic;
        div_active_i          : in  std_logic;
        fetched_instruction_i : in  std_logic_vector(31 downto 0);
        div_active_delayed_o  : out std_logic;
        held_instruction_o    : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of divider_instruction_latch is
    signal active_q      : std_logic;
    signal instruction_q : std_logic_vector(31 downto 0);
begin
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            active_q      <= '0';
            instruction_q <= (others => '0');
        elsif rising_edge(clk_i) then
            active_q <= div_active_i;
            if div_start_i = '1' then
                instruction_q <= fetched_instruction_i;
            end if;
        end if;
    end process;

    div_active_delayed_o <= active_q;
    held_instruction_o   <= instruction_q;
end architecture;
