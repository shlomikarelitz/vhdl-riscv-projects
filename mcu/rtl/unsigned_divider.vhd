library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity unsigned_divider is
    port (
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;
        start_i     : in  std_logic;
        dividend_i  : in  std_logic_vector(31 downto 0);
        divisor_i   : in  std_logic_vector(31 downto 0);
        
        busy_o      : out std_logic;
        done_o      : out std_logic;
        quotient_o  : out std_logic_vector(31 downto 0);
        remainder_o : out std_logic_vector(31 downto 0)
    );
end unsigned_divider;

architecture rtl of unsigned_divider is
    type state_type is (IDLE, CALC, DONE_STATE);
    signal state       : state_type;
    signal reg_q       : std_logic_vector(63 downto 0);
    signal divisor_reg : std_logic_vector(31 downto 0);
    signal count_q     : integer range 0 to 31;
begin

    process(clk_i, rst_i)
        variable sub_w : std_logic_vector(32 downto 0);
        variable next_q : std_logic_vector(63 downto 0);
    begin
        if rst_i = '1' then
            state       <= IDLE;
            reg_q       <= (others => '0');
            divisor_reg <= (others => '0');
            count_q     <= 0;
            busy_o      <= '0';
            done_o      <= '0';
            quotient_o  <= (others => '0');
            remainder_o <= (others => '0');
        elsif rising_edge(clk_i) then
            case state is
                when IDLE =>
                    done_o <= '0';
                    if start_i = '1' then
                        divisor_reg          <= divisor_i;
                        reg_q(31 downto 0)   <= dividend_i;
                        reg_q(63 downto 32)  <= (others => '0');
                        count_q              <= 0;
                        state                <= CALC;
                        busy_o               <= '1';
                    else
                        busy_o <= '0';
                    end if;
                
                when CALC =>
                    -- restoring division step
                    sub_w := ('0' & reg_q(62 downto 31)) - ('0' & divisor_reg);
                    if sub_w(32) = '0' then
                        next_q := sub_w(31 downto 0) & reg_q(30 downto 0) & '1';
                    else
                        next_q := reg_q(62 downto 0) & '0';
                    end if;
                    
                    reg_q <= next_q;
                    
                    if count_q = 31 then
                        quotient_o  <= next_q(31 downto 0);
                        remainder_o <= next_q(63 downto 32);
                        done_o      <= '1';
                        busy_o      <= '0';
                        state       <= IDLE;
                    else
                        count_q <= count_q + 1;
                    end if;
                
                when others =>
                    state <= IDLE;
            end case;
            
            -- Assertions
            -- synthesis translate_off
            if state = CALC then
                assert done_o = '0' report "Assertion Violation: Completion before 32 cycles" severity error;
            end if;
            if state = IDLE and done_o = '1' then
                assert busy_o = '0' report "Assertion Violation: busy_o is active during done_o" severity error;
            end if;
            -- synthesis translate_on
        end if;
    end process;

end rtl;
