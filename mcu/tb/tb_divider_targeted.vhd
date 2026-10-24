library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_divider_targeted is
end tb_divider_targeted;

architecture behavior of tb_divider_targeted is
    signal clk_50 : std_logic := '0';
    signal clk_25 : std_logic := '0';
    signal rst    : std_logic := '1';
    
    -- Divider engine signals
    signal div_start  : std_logic := '0';
    signal dividend   : std_logic_vector(31 downto 0) := (others => '0');
    signal divisor    : std_logic_vector(31 downto 0) := (others => '0');
    signal div_busy   : std_logic;
    signal div_done   : std_logic;
    signal quotient   : std_logic_vector(31 downto 0);
    signal remainder  : std_logic_vector(31 downto 0);
    
    -- Controller signals
    signal instruction : std_logic_vector(31 downto 0) := (others => '0');
    signal rs1_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal rs2_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal ctrl_result : std_logic_vector(31 downto 0);
    signal ctrl_req    : std_logic;
    signal ctrl_dividend : std_logic_vector(31 downto 0);
    signal ctrl_divisor  : std_logic_vector(31 downto 0);
    signal ctrl_pc_hold  : std_logic;
    signal ctrl_stall    : std_logic;
    signal ctrl_active   : std_logic;
    
    -- CDC signals
    signal ack_divclk    : std_logic;
    signal q_mclk        : std_logic_vector(31 downto 0);
    signal r_mclk        : std_logic_vector(31 downto 0);
    
    constant CLK_50_PERIOD : time := 20 ns;
    constant CLK_25_PERIOD : time := 40 ns;
begin

    -- Clock generation
    clk_50_proc: process
    begin
        clk_50 <= '0';
        wait for CLK_50_PERIOD/2;
        clk_50 <= '1';
        wait for CLK_50_PERIOD/2;
    end process;
    
    clk_25_proc: process
    begin
        clk_25 <= '0';
        wait for CLK_25_PERIOD/2;
        clk_25 <= '1';
        wait for CLK_25_PERIOD/2;
    end process;

    -- Instantiate Unsigned Divider Engine
    uut_div: entity work.unsigned_divider
    port map (
        clk_i       => clk_50,
        rst_i       => rst,
        start_i     => div_start,
        dividend_i  => dividend,
        divisor_i   => divisor,
        busy_o      => div_busy,
        done_o      => div_done,
        quotient_o  => quotient,
        remainder_o => remainder
    );

    -- Instantiate Divider Controller
    uut_ctrl: entity work.divider_controller
    generic map (
        G_HAS_DIVIDER => true
    )
    port map (
        clk_i               => clk_25,
        rst_i               => rst,
        instruction_i       => instruction,
        rs1_data_i          => rs1_data,
        rs2_data_i          => rs2_data,
        ack_divclk_i        => ack_divclk,
        quotient_divclk_i   => q_mclk,
        remainder_divclk_i  => r_mclk,
        req_divclk_o        => ctrl_req,
        dividend_o          => ctrl_dividend,
        divisor_o           => ctrl_divisor,
        result_o            => ctrl_result,
        pc_hold_o           => ctrl_pc_hold,
        divider_stall_o     => ctrl_stall,
        active_o            => ctrl_active
    );

    -- Instantiate Divider CDC Wrapper
    uut_cdc: entity work.divider_engine_cdc
    port map (
        clk_i               => clk_50,
        rst_i               => rst,
        req_mclk_i          => ctrl_req,
        dividend_mclk_i     => ctrl_dividend,
        divisor_mclk_i      => ctrl_divisor,
        ack_divclk_o        => ack_divclk,
        quotient_mclk_o     => q_mclk,
        remainder_mclk_o    => r_mclk
    );

    -- Test process
    stim_proc: process
        procedure test_unsigned_div(
            num : in std_logic_vector(31 downto 0);
            den : in std_logic_vector(31 downto 0);
            exp_q : in std_logic_vector(31 downto 0);
            exp_r : in std_logic_vector(31 downto 0)
        ) is
            variable start_time : time;
            variable elapsed : time;
            variable cycles : integer;
        begin
            wait until rising_edge(clk_50);
            dividend  <= num;
            divisor   <= den;
            div_start <= '1';
            wait until rising_edge(clk_50);
            div_start <= '0';
            start_time := now;
            
            wait for 31 * CLK_50_PERIOD;
            assert div_done = '0' report "Divider engine completed too early (at cycle 31)" severity failure;
            wait until div_done = '1';
            elapsed := now - start_time;
            cycles := integer(elapsed / CLK_50_PERIOD);
            
            assert cycles = 32 report "Divider engine must take exactly 32 clock cycles of calc" severity failure;
            assert quotient = exp_q report "Unsigned division quotient mismatch: got " & to_hstring(quotient) severity failure;
            assert remainder = exp_r report "Unsigned division remainder mismatch: got " & to_hstring(remainder) severity failure;
            
            wait for 50 ns;
        end procedure;
        
        procedure test_ctrl_op(
            inst_type : in std_logic_vector(2 downto 0); -- funct3
            val1      : in std_logic_vector(31 downto 0);
            val2      : in std_logic_vector(31 downto 0);
            exp_res   : in std_logic_vector(31 downto 0)
        ) is
        begin
            wait until rising_edge(clk_25);
            instruction <= "0000001" & "00000" & "00000" & inst_type & "00000" & "0110011"; -- RTYPE_OPC with funct7 = 0000001
            rs1_data <= val1;
            rs2_data <= val2;
            
            wait until ctrl_active = '1';
            
            -- Wait for completion or handshake finish
            if ctrl_pc_hold = '1' then
                wait until ctrl_pc_hold = '0';
            end if;
            
            -- The result should be stable and correct now
            assert ctrl_result = exp_res report "Controller result mismatch: got " & to_hstring(ctrl_result) & ", expected " & to_hstring(exp_res) severity failure;
            
            -- Reset instruction
            instruction <= (others => '0');
            wait until ctrl_active = '0';
            wait for 100 ns;
        end procedure;
        
    begin
        -- Initial reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;
        
        -- Part 1: Verify direct unsigned divider engine calculations & timing
        test_unsigned_div(std_logic_vector(to_unsigned(100, 32)), std_logic_vector(to_unsigned(3, 32)), std_logic_vector(to_unsigned(33, 32)), std_logic_vector(to_unsigned(1, 32)));
        test_unsigned_div(x"FFFFFFFF", std_logic_vector(to_unsigned(2, 32)), x"7FFFFFFF", x"00000001");
        test_unsigned_div(x"00000000", std_logic_vector(to_unsigned(10, 32)), x"00000000", x"00000000");
        test_unsigned_div(std_logic_vector(to_unsigned(50, 32)), std_logic_vector(to_unsigned(50, 32)), std_logic_vector(to_unsigned(1, 32)), x"00000000");
        
        -- Part 2: Verify controller & CDC operations
        -- 1. Signed Division (DIV, funct3 = 100)
        test_ctrl_op("100", std_logic_vector(to_signed(100, 32)), std_logic_vector(to_signed(3, 32)), std_logic_vector(to_signed(33, 32)));
        test_ctrl_op("100", std_logic_vector(to_signed(-100, 32)), std_logic_vector(to_signed(3, 32)), std_logic_vector(to_signed(-33, 32)));
        test_ctrl_op("100", std_logic_vector(to_signed(100, 32)), std_logic_vector(to_signed(-3, 32)), std_logic_vector(to_signed(-33, 32)));
        test_ctrl_op("100", std_logic_vector(to_signed(-100, 32)), std_logic_vector(to_signed(-3, 32)), std_logic_vector(to_signed(33, 32)));
        
        -- 2. Unsigned Division (DIVU, funct3 = 101)
        test_ctrl_op("101", std_logic_vector(to_unsigned(100, 32)), std_logic_vector(to_unsigned(3, 32)), std_logic_vector(to_unsigned(33, 32)));
        test_ctrl_op("101", x"FFFFFF9C", std_logic_vector(to_unsigned(3, 32)), x"55555534"); -- 4294967196 / 3 = 1431655732 (x"55555534")
        
        -- 3. Signed Remainder (REM, funct3 = 110)
        test_ctrl_op("110", std_logic_vector(to_signed(100, 32)), std_logic_vector(to_signed(3, 32)), std_logic_vector(to_signed(1, 32)));
        test_ctrl_op("110", std_logic_vector(to_signed(-100, 32)), std_logic_vector(to_signed(3, 32)), std_logic_vector(to_signed(-1, 32)));
        test_ctrl_op("110", std_logic_vector(to_signed(100, 32)), std_logic_vector(to_signed(-3, 32)), std_logic_vector(to_signed(1, 32)));
        test_ctrl_op("110", std_logic_vector(to_signed(-100, 32)), std_logic_vector(to_signed(-3, 32)), std_logic_vector(to_signed(-1, 32)));
        
        -- 4. Unsigned Remainder (REMU, funct3 = 111)
        test_ctrl_op("111", std_logic_vector(to_unsigned(100, 32)), std_logic_vector(to_unsigned(3, 32)), std_logic_vector(to_unsigned(1, 32)));
        
        -- 5. Special Cases: Division by Zero
        test_ctrl_op("100", std_logic_vector(to_signed(100, 32)), x"00000000", x"FFFFFFFF"); -- DIV by zero returns -1
        test_ctrl_op("101", std_logic_vector(to_signed(100, 32)), x"00000000", x"FFFFFFFF"); -- DIVU by zero returns 0xFFFFFFFF
        test_ctrl_op("110", std_logic_vector(to_signed(100, 32)), x"00000000", std_logic_vector(to_signed(100, 32))); -- REM by zero returns dividend
        test_ctrl_op("111", std_logic_vector(to_signed(100, 32)), x"00000000", std_logic_vector(to_signed(100, 32))); -- REMU by zero returns dividend
        
        -- 6. Special Cases: Signed Overflow
        test_ctrl_op("100", x"80000000", x"FFFFFFFF", x"80000000"); -- INT_MIN / -1 returns INT_MIN
        test_ctrl_op("110", x"80000000", x"FFFFFFFF", x"00000000"); -- INT_MIN % -1 returns 0
        
        report "PASS: tb_divider_targeted completed successfully." severity note;
        std.env.finish;
    end process;

end behavior;
