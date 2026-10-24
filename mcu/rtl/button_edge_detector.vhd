library ieee;
use ieee.std_logic_1164.all;

entity button_edge_detector is
    generic (
        WIDTH : positive := 3
    );
    port (
        clk_i         : in  std_logic;
        rst_i         : in  std_logic;  -- active-high
        pressed_i     : in  std_logic_vector(WIDTH-1 downto 0);
        press_pulse_o : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity button_edge_detector;

architecture rtl of button_edge_detector is
    signal previous_pressed : std_logic_vector(WIDTH-1 downto 0);
begin
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                previous_pressed <= (others => '0');
                press_pulse_o    <= (others => '0');
            else
                press_pulse_o    <= pressed_i and not previous_pressed;
                previous_pressed <= pressed_i;
            end if;
        end if;
    end process;
end architecture rtl;
