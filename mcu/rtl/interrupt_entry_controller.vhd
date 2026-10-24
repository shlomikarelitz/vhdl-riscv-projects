library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity interrupt_entry_controller is
    generic (
        PC_WIDTH       : integer := 10;
        DATA_BUS_WIDTH : integer := 32
    );
    port (
        clk_i                          : in  std_logic;
        rst_i                          : in  std_logic;
        irq_pending_raw_i              : in  std_logic;
        gie_i                          : in  std_logic;
        normal_next_pc_i               : in  std_logic_vector(PC_WIDTH-1 downto 0);
        data_bus_rdata_i               : in  std_logic_vector(DATA_BUS_WIDTH-1 downto 0);

        irq_take_now_o                 : out std_logic;
        irq_accept_pulse_o             : out std_logic;
        inta_n_o                       : out std_logic;
        force_type_address_o           : out std_logic;
        suppress_normal_side_effects_o : out std_logic;
        pc_hold_o                      : out std_logic;
        pc_force_en_o                  : out std_logic;
        pc_force_value_o               : out std_logic_vector(PC_WIDTH-1 downto 0);
        force_tp_write_o               : out std_logic;
        force_tp_data_o                : out std_logic_vector(DATA_BUS_WIDTH-1 downto 0);
        force_vector_address_o         : out std_logic;
        irq_service_pulse_o            : out std_logic;
        irq_service_type_o             : out std_logic_vector(7 downto 0);
        state_debug_o                  : out std_logic_vector(1 downto 0);
        divider_active_i               : in  std_logic := '0'
    );
end interrupt_entry_controller;

architecture rtl of interrupt_entry_controller is
    type state_t is (IRQ_NORMAL, IRQ_ENTRY_TYPE, IRQ_ENTRY_VECTOR);
    signal state_q       : state_t;
    signal return_pc_q   : std_logic_vector(PC_WIDTH-1 downto 0);
    signal type_vector_q : std_logic_vector(DATA_BUS_WIDTH-1 downto 0);
    
    signal irq_take_now_w : std_logic;
begin

    -- Combinational logic
    irq_take_now_w <= '1' when (state_q = IRQ_NORMAL and irq_pending_raw_i = '1' and gie_i = '1' and rst_i = '0' and divider_active_i = '0') else '0';
    irq_take_now_o <= irq_take_now_w;

    irq_accept_pulse_o <= '1' when (state_q = IRQ_ENTRY_TYPE and rst_i = '0') else '0';
    inta_n_o <= '0' when (state_q = IRQ_ENTRY_TYPE and rst_i = '0') else '1';
    
    force_type_address_o <= '1' when (state_q = IRQ_ENTRY_TYPE and rst_i = '0') else '0';
    
    suppress_normal_side_effects_o <= '1' when ((state_q = IRQ_ENTRY_TYPE or state_q = IRQ_ENTRY_VECTOR) and rst_i = '0') else '0';
    
    pc_hold_o <= '1' when (state_q = IRQ_ENTRY_TYPE and rst_i = '0') else '0';
    
    pc_force_en_o <= '1' when (state_q = IRQ_ENTRY_VECTOR and rst_i = '0') else '0';
    pc_force_value_o <= data_bus_rdata_i(PC_WIDTH-1 downto 0);

    force_vector_address_o <= '1' when (state_q = IRQ_ENTRY_VECTOR and rst_i = '0') else '0';
    
    force_tp_write_o <= '1' when (state_q = IRQ_ENTRY_VECTOR and rst_i = '0') else '0';
    force_tp_data_o(DATA_BUS_WIDTH-1 downto PC_WIDTH) <= (others => '0');
    force_tp_data_o(PC_WIDTH-1 downto 0) <= return_pc_q;
    
    irq_service_pulse_o <= '1' when (state_q = IRQ_ENTRY_VECTOR and rst_i = '0') else '0';
    irq_service_type_o <= type_vector_q(7 downto 0);
    
    state_debug_o <= "00" when state_q = IRQ_NORMAL else
                     "01" when state_q = IRQ_ENTRY_TYPE else
                     "10" when state_q = IRQ_ENTRY_VECTOR else "11";

    -- Sequential logic
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_q <= IRQ_NORMAL;
                return_pc_q <= (others => '0');
                type_vector_q <= (others => '0');
            else
                case state_q is
                    when IRQ_NORMAL =>
                        if irq_take_now_w = '1' then
                            return_pc_q <= normal_next_pc_i;
                            state_q <= IRQ_ENTRY_TYPE;
                        end if;
                        
                    when IRQ_ENTRY_TYPE =>
                        type_vector_q <= data_bus_rdata_i;
                        state_q <= IRQ_ENTRY_VECTOR;
                        
                    when IRQ_ENTRY_VECTOR =>
                        state_q <= IRQ_NORMAL;
                        
                    when others =>
                        state_q <= IRQ_NORMAL;
                end case;
            end if;
        end if;
    end process;

end rtl;
