library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity divider_engine_cdc is
    port (
        clk_i               : in  std_logic; -- DIVCLK (50 MHz)
        rst_i               : in  std_logic; -- raw async reset input
        
        -- Handshake inputs from MCLK domain
        req_mclk_i          : in  std_logic;
        dividend_mclk_i     : in  std_logic_vector(31 downto 0);
        divisor_mclk_i      : in  std_logic_vector(31 downto 0);
        
        -- Handshake outputs to MCLK domain
        ack_divclk_o        : out std_logic;
        quotient_mclk_o     : out std_logic_vector(31 downto 0);
        remainder_mclk_o    : out std_logic_vector(31 downto 0)
    );
end divider_engine_cdc;

architecture structural of divider_engine_cdc is
    type state_type is (IDLE, RUNNING, ACK_HIGH, ACK_LOW);
    signal state : state_type;
    
    -- Sync registers for req_mclk_i in DIVCLK domain
    signal req_sync_1 : std_logic;
    signal req_sync_2 : std_logic;
    
    -- Sync registers for reset in DIVCLK domain
    signal rst_sync_divclk_1 : std_logic;
    signal rst_sync_divclk_2 : std_logic;
    
    -- Divider instantiation signals
    signal start_divider : std_logic;
    signal dividend_reg  : std_logic_vector(31 downto 0);
    signal divisor_reg   : std_logic_vector(31 downto 0);
    
    signal busy_w        : std_logic;
    signal done_w        : std_logic;
    signal quotient_w    : std_logic_vector(31 downto 0);
    signal remainder_w   : std_logic_vector(31 downto 0);
    
    -- Stable outputs to MCLK domain
    signal q_reg         : std_logic_vector(31 downto 0);
    signal r_reg         : std_logic_vector(31 downto 0);
    signal ack_divclk_r  : std_logic;
begin

    -- Double-flop synchronizers
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            req_sync_1 <= '0';
            req_sync_2 <= '0';
            rst_sync_divclk_1 <= '1';
            rst_sync_divclk_2 <= '1';
        elsif rising_edge(clk_i) then
            req_sync_1 <= req_mclk_i;
            req_sync_2 <= req_sync_1;
            rst_sync_divclk_1 <= '0';
            rst_sync_divclk_2 <= rst_sync_divclk_1;
        end if;
    end process;

    -- Instantiate the unsigned divider engine
    DIV_ENGINE: entity work.unsigned_divider
    port map (
        clk_i       => clk_i,
        rst_i       => rst_sync_divclk_2,
        start_i     => start_divider,
        dividend_i  => dividend_reg,
        divisor_i   => divisor_reg,
        busy_o      => busy_w,
        done_o      => done_w,
        quotient_o  => quotient_w,
        remainder_o => remainder_w
    );

    -- Handshake state machine
    process(clk_i, rst_sync_divclk_2)
    begin
        if rst_sync_divclk_2 = '1' then
            state         <= IDLE;
            start_divider <= '0';
            dividend_reg  <= (others => '0');
            divisor_reg   <= (others => '0');
            q_reg         <= (others => '0');
            r_reg         <= (others => '0');
            ack_divclk_r  <= '0';
        elsif rising_edge(clk_i) then
            case state is
                when IDLE =>
                    ack_divclk_r  <= '0';
                    start_divider <= '0';
                    if req_sync_2 = '1' then
                        dividend_reg  <= dividend_mclk_i;
                        divisor_reg   <= divisor_mclk_i;
                        start_divider <= '1';
                        state         <= RUNNING;
                    end if;
                    
                when RUNNING =>
                    start_divider <= '0';
                    if done_w = '1' then
                        q_reg <= quotient_w;
                        r_reg <= remainder_w;
                        state <= ACK_HIGH;
                    end if;
                    
                when ACK_HIGH =>
                    ack_divclk_r <= '1';
                    if req_sync_2 = '0' then
                        state <= ACK_LOW;
                    end if;
                    
                when ACK_LOW =>
                    ack_divclk_r <= '0';
                    state        <= IDLE;
            end case;
        end if;
    end process;

    ack_divclk_o     <= ack_divclk_r;
    quotient_mclk_o  <= q_reg;
    remainder_mclk_o <= r_reg;

end structural;
