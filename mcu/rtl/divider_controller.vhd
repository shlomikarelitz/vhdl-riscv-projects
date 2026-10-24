library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.const_package.all;

entity divider_controller is
    generic (
        G_HAS_DIVIDER : boolean := false
    );
    port (
        clk_i               : in  std_logic; -- MCLK (25 MHz)
        rst_i               : in  std_logic;
        
        -- Instruction decode inputs
        instruction_i       : in  std_logic_vector(31 downto 0);
        rs1_data_i          : in  std_logic_vector(31 downto 0);
        rs2_data_i          : in  std_logic_vector(31 downto 0);
        
        -- Divider engine inputs (from DIVCLK domain via synchronizers)
        ack_divclk_i        : in  std_logic;
        quotient_divclk_i   : in  std_logic_vector(31 downto 0);
        remainder_divclk_i  : in  std_logic_vector(31 downto 0);
        
        -- Control outputs
        req_divclk_o        : out std_logic;
        dividend_o          : out std_logic_vector(31 downto 0);
        divisor_o           : out std_logic_vector(31 downto 0);
        result_o            : out std_logic_vector(31 downto 0);
        
        pc_hold_o           : out std_logic;
        divider_stall_o     : out std_logic;
        active_o            : out std_logic;
        is_div_instr_o      : out std_logic;
        div_start_o         : out std_logic
    );
end divider_controller;

architecture rtl of divider_controller is
    type state_type is (IDLE, WAIT_ACK_HIGH, WAIT_ACK_LOW, DONE_ONE_CYCLE);
    signal state_q : state_type;
    
    -- Sync registers for ack_divclk_i
    signal ack_sync_1 : std_logic;
    signal ack_sync_2 : std_logic;
    
    -- Internal control signals
    signal is_div_instr_w : std_logic;
    signal is_div_by_zero_w : std_logic;
    signal is_signed_overflow_w : std_logic;
    signal is_unsigned_w : std_logic;
    
    -- Operand register files
    signal funct3_reg : std_logic_vector(2 downto 0);
    signal rd_reg     : std_logic_vector(4 downto 0);
    signal dividend_is_neg : std_logic;
    signal divisor_is_neg  : std_logic;
    signal dividend_is_neg_reg : std_logic;
    signal divisor_is_neg_reg  : std_logic;
    signal is_unsigned_reg     : std_logic;
    
    signal req_mclk : std_logic;
    signal result_reg : std_logic_vector(31 downto 0);
    
    -- Absolute value conversions
    signal abs_dividend : std_logic_vector(31 downto 0);
    signal abs_divisor  : std_logic_vector(31 downto 0);
begin

    -- Decode logic
    is_div_instr_w <= '1' when (instruction_i(6 downto 0) = RTYPE_OPC and 
                               instruction_i(31 downto 25) = "0000001" and 
                               (instruction_i(14 downto 12) = "100" or 
                                instruction_i(14 downto 12) = "101" or 
                                instruction_i(14 downto 12) = "110" or 
                                instruction_i(14 downto 12) = "111")) else '0';
                                
    is_unsigned_w <= '1' when (instruction_i(14 downto 12) = "101" or instruction_i(14 downto 12) = "111") else '0';
    
    -- Special cases
    is_div_by_zero_w <= '1' when (rs2_data_i = x"00000000" and is_div_instr_w = '1') else '0';
    is_signed_overflow_w <= '1' when (rs1_data_i = x"80000000" and rs2_data_i = x"FFFFFFFF" and is_unsigned_w = '0' and is_div_instr_w = '1') else '0';

    -- Double-flop synchronizer for ack
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            ack_sync_1 <= '0';
            ack_sync_2 <= '0';
        elsif rising_edge(clk_i) then
            ack_sync_1 <= ack_divclk_i;
            ack_sync_2 <= ack_sync_1;
        end if;
    end process;

    -- Sign detection & absolute values
    dividend_is_neg <= rs1_data_i(31) when (instruction_i(14) = '1' and instruction_i(13 downto 12) /= "01" and instruction_i(13 downto 12) /= "11") else '0';
    divisor_is_neg  <= rs2_data_i(31) when (instruction_i(14) = '1' and instruction_i(13 downto 12) /= "01" and instruction_i(13 downto 12) /= "11") else '0';
    
    abs_dividend <= std_logic_vector(-signed(rs1_data_i)) when dividend_is_neg = '1' else rs1_data_i;
    abs_divisor  <= std_logic_vector(-signed(rs2_data_i)) when divisor_is_neg = '1' else rs2_data_i;

    req_divclk_o <= req_mclk;

    -- Combinational active_o assignment
    active_o <= '1' when (state_q = WAIT_ACK_HIGH or 
                          state_q = WAIT_ACK_LOW or 
                          state_q = DONE_ONE_CYCLE or 
                          (state_q = IDLE and is_div_instr_w = '1')) else '0';

    -- Combinational stall signals assignments
    pc_hold_o <= '1' when (state_q = WAIT_ACK_HIGH or 
                           state_q = WAIT_ACK_LOW or 
                           (state_q = IDLE and is_div_instr_w = '1' and G_HAS_DIVIDER = true)) else '0';

    divider_stall_o <= '1' when (state_q = WAIT_ACK_HIGH or 
                                 state_q = WAIT_ACK_LOW or 
                                 (state_q = IDLE and is_div_instr_w = '1' and G_HAS_DIVIDER = true)) else '0';
                                 
    is_div_instr_o <= is_div_instr_w;
    div_start_o <= '1' when (state_q = IDLE and is_div_instr_w = '1') else '0';

    -- Controller process
    process(clk_i, rst_i)
        variable quotient_raw : std_logic_vector(31 downto 0);
        variable remainder_raw : std_logic_vector(31 downto 0);
        variable quotient_final : std_logic_vector(31 downto 0);
        variable remainder_final : std_logic_vector(31 downto 0);
        variable q_neg : std_logic;
        variable r_neg : std_logic;
    begin
        if rst_i = '1' then
            state_q             <= IDLE;
            req_mclk            <= '0';
            result_reg          <= (others => '0');
            dividend_o          <= (others => '0');
            divisor_o           <= (others => '0');
            funct3_reg          <= (others => '0');
            rd_reg              <= (others => '0');
            dividend_is_neg_reg <= '0';
            divisor_is_neg_reg  <= '0';
            is_unsigned_reg     <= '0';
        elsif rising_edge(clk_i) then
            case state_q is
                when IDLE =>
                    if is_div_instr_w = '1' then
                        funct3_reg          <= instruction_i(14 downto 12);
                        rd_reg              <= instruction_i(11 downto 7);
                        dividend_is_neg_reg <= dividend_is_neg;
                        divisor_is_neg_reg  <= divisor_is_neg;
                        is_unsigned_reg     <= is_unsigned_w;
                        
                        -- Special cases: division by zero or signed overflow
                        if G_HAS_DIVIDER = false then
                            result_reg <= (others => '0');
                            state_q <= IDLE;
                        else
                            if is_div_by_zero_w = '1' then
                                if instruction_i(14 downto 12) = "100" or instruction_i(14 downto 12) = "101" then
                                    result_reg <= (others => '1'); -- DIV/DIVU by zero returns 0xFFFFFFFF (-1)
                                else
                                    result_reg <= rs1_data_i;      -- REM/REMU by zero returns dividend
                                end if;
                                state_q <= DONE_ONE_CYCLE;
                            elsif is_signed_overflow_w = '1' then
                                if instruction_i(14 downto 12) = "100" then
                                    result_reg <= x"80000000"; -- DIV signed overflow returns INT_MIN
                                else
                                    result_reg <= (others => '0'); -- REM signed overflow returns 0
                                end if;
                                state_q <= DONE_ONE_CYCLE;
                            else
                                -- Start CDC divider handshake
                                dividend_o <= abs_dividend;
                                divisor_o  <= abs_divisor;
                                req_mclk   <= '1';
                                state_q    <= WAIT_ACK_HIGH;
                            end if;
                        end if;
                    else
                        req_mclk <= '0';
                    end if;
                    
                when WAIT_ACK_HIGH =>
                    req_mclk   <= '1';
                    
                    if ack_sync_2 = '1' then
                        -- Divider has finished. Grab the results.
                        quotient_raw := quotient_divclk_i;
                        remainder_raw := remainder_divclk_i;
                        
                        -- Signed correction using registered flags
                        q_neg := dividend_is_neg_reg xor divisor_is_neg_reg;
                        r_neg := dividend_is_neg_reg;
                        
                        if q_neg = '1' then
                            quotient_final := std_logic_vector(-signed(quotient_raw));
                        else
                            quotient_final := quotient_raw;
                        end if;
                        
                        if r_neg = '1' then
                            remainder_final := std_logic_vector(-signed(remainder_raw));
                        else
                            remainder_final := remainder_raw;
                        end if;
                        
                        -- Place final result based on funct3
                        if funct3_reg = "100" or funct3_reg = "101" then
                            result_reg <= quotient_final;
                        else
                            result_reg <= remainder_final;
                        end if;
                        
                        req_mclk <= '0';
                        state_q  <= WAIT_ACK_LOW;
                    end if;
                    
                when WAIT_ACK_LOW =>
                    req_mclk <= '0';
                    
                    if ack_sync_2 = '0' then
                        state_q <= DONE_ONE_CYCLE;
                    end if;
                    
                when DONE_ONE_CYCLE =>
                    -- Stall released, result written to RF
                    state_q <= IDLE;
            end case;
        end if;
    end process;

    result_o <= result_reg;

end rtl;
