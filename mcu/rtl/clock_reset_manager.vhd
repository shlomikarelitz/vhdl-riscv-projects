LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY clock_reset_manager IS
    GENERIC (
        MODELSIM : integer := 0
    );
    PORT (
        clk_i          : IN  std_logic;
        rst_n_i        : IN  std_logic;
        
        mclk_o         : OUT std_logic;
        divclk_o       : OUT std_logic;
        rst_internal_o : OUT std_logic
    );
END clock_reset_manager;

ARCHITECTURE behavior OF clock_reset_manager IS
    COMPONENT PLL IS
        PORT (
            areset : IN  std_logic;
            inclk0 : IN  std_logic;
            c0     : OUT std_logic;
            locked : OUT std_logic
        );
    END COMPONENT;

    SIGNAL mclk_w        : std_logic;
    SIGNAL rst_req_async : std_logic;
    SIGNAL rst_sync_1    : std_logic;
    SIGNAL rst_sync_2    : std_logic;
    SIGNAL pll_locked_w  : std_logic;
    SIGNAL pll_areset_w  : std_logic;
BEGIN

    pll_areset_w <= not rst_n_i;
    rst_req_async <= (not rst_n_i) or (not pll_locked_w);

    G_PLL: IF MODELSIM = 0 GENERATE
        PLL_inst : PLL
        PORT MAP (
            areset => pll_areset_w,
            inclk0 => clk_i,
            c0     => mclk_w,
            locked => pll_locked_w
        );
    ELSE GENERATE
        mclk_w <= clk_i;
        pll_locked_w <= '1';
    END GENERATE G_PLL;

    -- Reset Synchronizer
    PROCESS(mclk_w, rst_req_async)
    BEGIN
        IF rst_req_async = '1' THEN
            rst_sync_1 <= '1';
            rst_sync_2 <= '1';
        ELSIF rising_edge(mclk_w) THEN
            rst_sync_1 <= '0';
            rst_sync_2 <= rst_sync_1;
        END IF;
    END PROCESS;

    mclk_o         <= mclk_w;
    divclk_o       <= clk_i;
    rst_internal_o <= rst_sync_2;

END behavior;
