library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_simple_mcu is
    -- No ports in a testbench
end entity tb_simple_mcu;

architecture behavior of tb_simple_mcu is

    -- Clock period definition
    constant CLK_PERIOD : time := 20 ns; -- 50 MHz

    -- Signals to connect to the MCU
    signal clk_i    : std_logic := '0';
    signal rst_n_i  : std_logic := '0';
    signal KEY_n_i  : std_logic_vector(3 downto 1) := "111";
    signal SW_i     : std_logic_vector(9 downto 0) := (others => '0');
    signal CAPIN1_i : std_logic := '0';
    signal CAPIN2_i : std_logic := '0';
    
    signal PWMout_o : std_logic;
    signal LEDR_o   : std_logic_vector(9 downto 0);
    signal HEX0_o   : std_logic_vector(6 downto 0);
    signal HEX1_o   : std_logic_vector(6 downto 0);
    signal HEX2_o   : std_logic_vector(6 downto 0);
    signal HEX3_o   : std_logic_vector(6 downto 0);
    signal HEX4_o   : std_logic_vector(6 downto 0);
    signal HEX5_o   : std_logic_vector(6 downto 0);

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT: entity work.RV32IM_MCU
        generic map (
            -- You can change these to point to your desired HEX files
            ITCM_INIT_FILE => "programs/interrupt_demo/ITCM.hex",
            DTCM_INIT_FILE => "programs/interrupt_demo/DTCM.hex",
            MODELSIM       => 1
        )
        port map (
            clk_i    => clk_i,
            rst_n_i  => rst_n_i,
            KEY_n_i  => KEY_n_i,
            SW_i     => SW_i,
            CAPIN1_i => CAPIN1_i,
            CAPIN2_i => CAPIN2_i,
            PWMout_o => PWMout_o,
            LEDR_o   => LEDR_o,
            HEX0_o   => HEX0_o,
            HEX1_o   => HEX1_o,
            HEX2_o   => HEX2_o,
            HEX3_o   => HEX3_o,
            HEX4_o   => HEX4_o,
            HEX5_o   => HEX5_o
        );

    -- Clock process
    clk_process: process
    begin
        clk_i <= '0';
        wait for CLK_PERIOD / 2;
        clk_i <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus process (Simulating user actions)
    stimulus: process
    begin
        -- 1. Reset the system
        rst_n_i <= '0';
        wait for 100 ns;
        rst_n_i <= '1';
        
        -- Wait a bit for initialization
        wait for 500 ns;
        
        -- 2. Simulate pressing KEY1 (Active Low)
        KEY_n_i(1) <= '0';
        wait for 200 ns;
        KEY_n_i(1) <= '1';
        
        -- Wait for the interrupt to be handled
        wait for 20 us;

        -- 3. Simulate pressing KEY2
        KEY_n_i(2) <= '0';
        wait for 200 ns;
        KEY_n_i(2) <= '1';
        
        wait for 20 us;
        
        -- 4. Simulate pressing KEY3
        KEY_n_i(3) <= '0';
        wait for 200 ns;
        KEY_n_i(3) <= '1';

        -- Wait forever to let the simulation run
        wait;
    end process;

end architecture behavior;
