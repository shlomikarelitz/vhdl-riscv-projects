library ieee;
use ieee.std_logic_1164.all;

entity gpio_pushbuttons is
    port (
        clk_i              : in  std_logic;
        rst_i              : in  std_logic;
        
        -- Physical pins
        KEY_n_i            : in  std_logic_vector(3 downto 1);
        
        -- Outputs to MMIO Decoder and Interrupt Controller
        pb_rdata_o         : out std_logic_vector(31 downto 0);
        pb_press_pulse_o   : out std_logic_vector(3 downto 1)
    );
end entity gpio_pushbuttons;

architecture struct of gpio_pushbuttons is

    component input_synchronizer is
        generic (
            WIDTH : positive := 3
        );
        port (
            clk_i          : in  std_logic;
            rst_i          : in  std_logic;
            async_i        : in  std_logic_vector(WIDTH-1 downto 0);
            synchronized_o : out std_logic_vector(WIDTH-1 downto 0)
        );
    end component;

    component button_edge_detector is
        generic (
            WIDTH : positive := 3
        );
        port (
            clk_i         : in  std_logic;
            rst_i         : in  std_logic;
            pressed_i     : in  std_logic_vector(WIDTH-1 downto 0);
            press_pulse_o : out std_logic_vector(WIDTH-1 downto 0)
        );
    end component;

    -- Internal signals
    signal key_async_n    : std_logic_vector(2 downto 0);
    signal key_sync_n     : std_logic_vector(2 downto 0);
    signal pressed_level  : std_logic_vector(2 downto 0);
    signal press_pulse    : std_logic_vector(2 downto 0);

begin

    -- Explicit mapping from index (3 downto 1) to internal (2 downto 0)
    key_async_n(0) <= KEY_n_i(1);
    key_async_n(1) <= KEY_n_i(2);
    key_async_n(2) <= KEY_n_i(3);

    u_sync: input_synchronizer
        generic map (WIDTH => 3)
        port map (
            clk_i          => clk_i,
            rst_i          => rst_i,
            async_i        => key_async_n,
            synchronized_o => key_sync_n
        );

    -- Normalize polarity after synchronization
    pressed_level <= not key_sync_n;

    u_edge_detector: button_edge_detector
        generic map (WIDTH => 3)
        port map (
            clk_i         => clk_i,
            rst_i         => rst_i,
            pressed_i     => pressed_level,
            press_pulse_o => press_pulse
        );

    -- Map internal pulse (2 downto 0) back to output (3 downto 1)
    pb_press_pulse_o(1) <= press_pulse(0);
    pb_press_pulse_o(2) <= press_pulse(1);
    pb_press_pulse_o(3) <= press_pulse(2);

    -- Explicit mapping to PORT_PB data output
    pb_rdata_o(0) <= '0';
    pb_rdata_o(1) <= pressed_level(0);
    pb_rdata_o(2) <= pressed_level(1);
    pb_rdata_o(3) <= pressed_level(2);
    pb_rdata_o(31 downto 4) <= (others => '0');

end architecture struct;
