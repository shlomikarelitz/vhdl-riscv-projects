LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY RV32IM_MCU IS
	generic( 
		ITCM_INIT_FILE   : string := "ITCM.hex";
		DTCM_INIT_FILE   : string := "DTCM.hex";
		WORD_GRANULARITY : boolean := true;
		MODELSIM         : integer := 0
	);
	PORT(	
		clk_i    : IN  STD_LOGIC;
		rst_n_i  : IN  STD_LOGIC; -- KEY0
		
		-- GPIO Ports
		KEY_n_i  : IN  STD_LOGIC_VECTOR(3 DOWNTO 1);
		SW_i     : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
		CAPIN1_i : IN  STD_LOGIC;
		CAPIN2_i : IN  STD_LOGIC;
		PWMout_o : OUT STD_LOGIC;
		LEDR_o   : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
		HEX0_o   : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX1_o   : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX2_o   : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX3_o   : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX4_o   : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX5_o   : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END RV32IM_MCU;

ARCHITECTURE structural OF RV32IM_MCU IS

	-- Core Component
	COMPONENT RV32I_CORE
		generic( 
			G_HAS_DIVIDER    : boolean := false;
			ITCM_INIT_FILE   : string;
			DTCM_INIT_FILE   : string;
			WORD_GRANULARITY : boolean
		);
		PORT(	
			rst_i            : IN  STD_LOGIC;
			clk_i            : IN  STD_LOGIC;
			irq_pending_raw_i: IN  STD_LOGIC;
			inta_n_o         : OUT STD_LOGIC;
			irq_service_pulse_o: OUT STD_LOGIC;
			irq_service_type_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			
			-- MMIO Interface
			data_addr_o      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			data_wdata_o     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			data_rdata_i     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			data_read_o      : OUT STD_LOGIC;
			data_write_o     : OUT STD_LOGIC;
			data_funct3_o    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
			
			-- Divider handshake
			div_req_o        : OUT STD_LOGIC;
			div_ack_i        : IN  STD_LOGIC;
			div_dividend_o   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			div_divisor_o    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			div_quotient_i   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			div_remainder_i  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT;

	-- Clock/Reset Manager
	COMPONENT clock_reset_manager
		GENERIC (
			MODELSIM : integer := 0
		);
		PORT(
			clk_i          : IN  STD_LOGIC;
			rst_n_i        : IN  STD_LOGIC;
			mclk_o         : OUT STD_LOGIC;
			divclk_o       : OUT STD_LOGIC;
			rst_internal_o : OUT STD_LOGIC
		);
	END COMPONENT;

	-- MMIO Components
	COMPONENT mmio_address_decoder
		PORT (
			data_addr_i    : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
			mmio_sel_i     : IN  STD_LOGIC;
			mmio_read_i    : IN  STD_LOGIC;
			sw_rdata_i     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			pb_rdata_i     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			ie_rdata_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			ifg_rdata_i    : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			type_rdata_i   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			btctl1_i       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			btctl2_i       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			btcmpr0_i      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			btcmpr1_i      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			btcapr_i       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			mmio_rdata_o   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			cs_ledr_o      : OUT STD_LOGIC;
			cs_hex0_o      : OUT STD_LOGIC;
			cs_hex1_o      : OUT STD_LOGIC;
			cs_hex2_o      : OUT STD_LOGIC;
			cs_hex3_o      : OUT STD_LOGIC;
			cs_hex4_o      : OUT STD_LOGIC;
			cs_hex5_o      : OUT STD_LOGIC;
			cs_sw_o        : OUT STD_LOGIC;
			cs_pb_o        : OUT STD_LOGIC;
			cs_ie_o        : OUT STD_LOGIC;
			cs_ifg_o       : OUT STD_LOGIC;
			cs_type_o      : OUT STD_LOGIC;
			cs_btctl1_o    : OUT STD_LOGIC;
			cs_btctl2_o    : OUT STD_LOGIC;
			cs_btcmpr0_o   : OUT STD_LOGIC;
			cs_btcmpr1_o   : OUT STD_LOGIC;
			cs_btcapr_o    : OUT STD_LOGIC
		);
	END COMPONENT;

	COMPONENT basic_timer
		PORT (
			clk_i          : IN  STD_LOGIC;
			rst_i          : IN  STD_LOGIC;
			mmio_write_i   : IN  STD_LOGIC;
			wdata_i        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			cs_btctl1_i    : IN  STD_LOGIC;
			cs_btctl2_i    : IN  STD_LOGIC;
			cs_btcmpr0_i   : IN  STD_LOGIC;
			cs_btcmpr1_i   : IN  STD_LOGIC;
			capin1_i       : IN  STD_LOGIC;
			capin2_i       : IN  STD_LOGIC;
			pwmout_o       : OUT STD_LOGIC;
			btctl1_o       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			btctl2_o       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			btcmpr0_o      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			btcmpr1_o      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			btcapr_o       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			timer_event_o  : OUT STD_LOGIC
		);
	END COMPONENT;

	COMPONENT gpio_ledr
		PORT (
			clk_i       : IN  STD_LOGIC;
			rst_i       : IN  STD_LOGIC;
			cs_i        : IN  STD_LOGIC;
			mem_write_i : IN  STD_LOGIC;
			wdata_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			ledr_o      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT hex_display_regs
		PORT (
			clk_i       : IN  STD_LOGIC;
			rst_i       : IN  STD_LOGIC;
			mem_write_i : IN  STD_LOGIC;
			wdata_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			cs_hex0_i   : IN  STD_LOGIC;
			cs_hex1_i   : IN  STD_LOGIC;
			cs_hex2_i   : IN  STD_LOGIC;
			cs_hex3_i   : IN  STD_LOGIC;
			cs_hex4_i   : IN  STD_LOGIC;
			cs_hex5_i   : IN  STD_LOGIC;
			hex0_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex1_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex2_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex3_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex4_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex5_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT gpio_switches
		PORT (
			sw_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			rdata_o  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT gpio_pushbuttons
		PORT (
			clk_i              : IN  STD_LOGIC;
			rst_i              : IN  STD_LOGIC;
			KEY_n_i            : IN  STD_LOGIC_VECTOR(3 DOWNTO 1);
			pb_rdata_o         : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			pb_press_pulse_o   : OUT STD_LOGIC_VECTOR(3 DOWNTO 1)
		);
	END COMPONENT;

	COMPONENT interrupt_controller
		PORT (
			clk_i             : IN  STD_LOGIC;
			rst_i             : IN  STD_LOGIC;
			inta_n_i          : IN  STD_LOGIC;
			irq_service_pulse_i: IN  STD_LOGIC;
			irq_service_type_i : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			event_i           : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			mmio_write_i      : IN  STD_LOGIC;
			cs_ie_i           : IN  STD_LOGIC;
			cs_ifg_i          : IN  STD_LOGIC;
			wdata_i           : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			ie_rdata_o        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			ifg_rdata_o       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			type_rdata_o      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			irq_pending_raw_o : OUT STD_LOGIC
		);
	END COMPONENT;

	-- Signals
	SIGNAL mclk_w         : STD_LOGIC;
	SIGNAL divclk_w       : STD_LOGIC;
	SIGNAL sys_rst_w      : STD_LOGIC;
	
	-- Divider Handshake
	SIGNAL div_req_w      : STD_LOGIC;
	SIGNAL div_ack_w      : STD_LOGIC;
	SIGNAL div_dividend_w : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL div_divisor_w  : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL div_quotient_w : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL div_remainder_w: STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	SIGNAL mmio_addr_w    : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL mmio_wdata_w   : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL mmio_rdata_w   : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL mmio_read_w    : STD_LOGIC;
	SIGNAL mmio_write_w   : STD_LOGIC;
	SIGNAL mmio_sel_w     : STD_LOGIC;
	
	SIGNAL cs_ledr_w      : STD_LOGIC;
	SIGNAL cs_hex0_w      : STD_LOGIC;
	SIGNAL cs_hex1_w      : STD_LOGIC;
	SIGNAL cs_hex2_w      : STD_LOGIC;
	SIGNAL cs_hex3_w      : STD_LOGIC;
	SIGNAL cs_hex4_w      : STD_LOGIC;
	SIGNAL cs_hex5_w      : STD_LOGIC;
	SIGNAL cs_sw_w        : STD_LOGIC;
	SIGNAL cs_pb_w        : STD_LOGIC;
	SIGNAL cs_ie_w        : STD_LOGIC;
	SIGNAL cs_ifg_w       : STD_LOGIC;
	SIGNAL cs_type_w      : STD_LOGIC;
	
	SIGNAL cs_btctl1_w    : STD_LOGIC;
	SIGNAL cs_btctl2_w    : STD_LOGIC;
	SIGNAL cs_btcmpr0_w   : STD_LOGIC;
	SIGNAL cs_btcmpr1_w   : STD_LOGIC;
	SIGNAL cs_btcapr_w    : STD_LOGIC;
	
	SIGNAL btctl1_w       : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL btctl2_w       : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL btcmpr0_w      : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL btcmpr1_w      : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL btcapr_w       : STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	SIGNAL sw_rdata_w     : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL pb_rdata_w     : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL pb_press_pulse_w : STD_LOGIC_VECTOR(3 DOWNTO 1);
	
	SIGNAL interrupt_event_w : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL ie_rdata_w        : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ifg_rdata_w       : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL type_rdata_w      : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL irq_pending_raw_w : STD_LOGIC;
	SIGNAL inta_n_w          : STD_LOGIC;
	SIGNAL irq_service_pulse_w : STD_LOGIC;
	SIGNAL irq_service_type_w  : STD_LOGIC_VECTOR(7 DOWNTO 0);
	
BEGIN

	-- Drive fixed outputs
	LEDR_o(9 DOWNTO 8) <= "00";
	-- SW_i(9 downto 8) are ignored internally

	-- Clock & Reset Manager
	clk_rst_mgr: clock_reset_manager
	GENERIC MAP (
		MODELSIM => MODELSIM
	)
	PORT MAP (
		clk_i          => clk_i,
		rst_n_i        => rst_n_i,
		mclk_o         => mclk_w,
		divclk_o       => divclk_w,
		rst_internal_o => sys_rst_w
	);

	-- Core Instantiation
	core: RV32I_CORE
	GENERIC MAP(
		G_HAS_DIVIDER    => true,
		ITCM_INIT_FILE   => ITCM_INIT_FILE,
		DTCM_INIT_FILE   => DTCM_INIT_FILE,
		WORD_GRANULARITY => WORD_GRANULARITY
	)
	PORT MAP (
		clk_i          => mclk_w,
		rst_i          => sys_rst_w,
		irq_pending_raw_i => irq_pending_raw_w,
		inta_n_o       => inta_n_w,
		irq_service_pulse_o => irq_service_pulse_w,
		irq_service_type_o  => irq_service_type_w,
		
		data_addr_o    => mmio_addr_w,
		data_wdata_o   => mmio_wdata_w,
		data_rdata_i   => mmio_rdata_w,
		data_read_o    => mmio_read_w,
		data_write_o   => mmio_write_w,
		data_funct3_o  => open,
		
		-- Divider handshake
		div_req_o      => div_req_w,
		div_ack_i      => div_ack_w,
		div_dividend_o => div_dividend_w,
		div_divisor_o  => div_divisor_w,
		div_quotient_i => div_quotient_w,
		div_remainder_i => div_remainder_w
	);

	-- Divider Engine with CDC Handshake Instantiation
	div_engine: entity work.divider_engine_cdc
	PORT MAP (
		clk_i            => divclk_w,
		rst_i            => sys_rst_w,
		req_mclk_i       => div_req_w,
		dividend_mclk_i  => div_dividend_w,
		divisor_mclk_i   => div_divisor_w,
		ack_divclk_o     => div_ack_w,
		quotient_mclk_o  => div_quotient_w,
		remainder_mclk_o => div_remainder_w
	);

	-- Derived MMIO Select
	mmio_sel_w <= mmio_read_w OR mmio_write_w;

	-- Address Decoder
	decoder: mmio_address_decoder
	PORT MAP (
		data_addr_i    => mmio_addr_w(13 DOWNTO 0),
		mmio_sel_i     => mmio_sel_w,
		mmio_read_i    => mmio_read_w,
		
		sw_rdata_i     => sw_rdata_w,
		pb_rdata_i     => pb_rdata_w,
		ie_rdata_i     => ie_rdata_w,
		ifg_rdata_i    => ifg_rdata_w,
		type_rdata_i   => type_rdata_w,
		btctl1_i       => btctl1_w,
		btctl2_i       => btctl2_w,
		btcmpr0_i      => btcmpr0_w,
		btcmpr1_i      => btcmpr1_w,
		btcapr_i       => btcapr_w,
		mmio_rdata_o   => mmio_rdata_w,
		
		cs_ledr_o      => cs_ledr_w,
		cs_hex0_o      => cs_hex0_w,
		cs_hex1_o      => cs_hex1_w,
		cs_hex2_o      => cs_hex2_w,
		cs_hex3_o      => cs_hex3_w,
		cs_hex4_o      => cs_hex4_w,
		cs_hex5_o      => cs_hex5_w,
		cs_sw_o        => cs_sw_w,
		cs_pb_o        => cs_pb_w,
		cs_ie_o        => cs_ie_w,
		cs_ifg_o       => cs_ifg_w,
		cs_type_o      => cs_type_w,
		cs_btctl1_o    => cs_btctl1_w,
		cs_btctl2_o    => cs_btctl2_w,
		cs_btcmpr0_o   => cs_btcmpr0_w,
		cs_btcmpr1_o   => cs_btcmpr1_w,
		cs_btcapr_o    => cs_btcapr_w
	);

	-- LEDR Peripheral
	ledr_inst: gpio_ledr
	PORT MAP (
		clk_i       => mclk_w,
		rst_i       => sys_rst_w,
		cs_i        => cs_ledr_w,
		mem_write_i => mmio_write_w,
		wdata_i     => mmio_wdata_w(7 DOWNTO 0),
		ledr_o      => LEDR_o(7 DOWNTO 0)
	);

	-- HEX Displays Peripheral
	hex_inst: hex_display_regs
	PORT MAP (
		clk_i       => mclk_w,
		rst_i       => sys_rst_w,
		mem_write_i => mmio_write_w,
		wdata_i     => mmio_wdata_w(7 DOWNTO 0),
		cs_hex0_i   => cs_hex0_w,
		cs_hex1_i   => cs_hex1_w,
		cs_hex2_i   => cs_hex2_w,
		cs_hex3_i   => cs_hex3_w,
		cs_hex4_i   => cs_hex4_w,
		cs_hex5_i   => cs_hex5_w,
		hex0_o      => HEX0_o,
		hex1_o      => HEX1_o,
		hex2_o      => HEX2_o,
		hex3_o      => HEX3_o,
		hex4_o      => HEX4_o,
		hex5_o      => HEX5_o
	);

	-- SW Peripheral
	sw_inst: gpio_switches
	PORT MAP (
		sw_i        => SW_i(7 DOWNTO 0),
		rdata_o     => sw_rdata_w
	);

	-- Pushbuttons Peripheral
	pb_inst: gpio_pushbuttons
	PORT MAP (
		clk_i              => mclk_w,
		rst_i              => sys_rst_w,
		KEY_n_i            => KEY_n_i,
		pb_rdata_o         => pb_rdata_w,
		pb_press_pulse_o   => pb_press_pulse_w
	);

	-- Interrupt Controller Front-End
	interrupt_event_w(0) <= '0'; -- UART RX reserved (bonus peripheral absent)
	interrupt_event_w(1) <= '0'; -- UART TX reserved (bonus peripheral absent)
	
	timer_inst: basic_timer
	PORT MAP (
		clk_i          => mclk_w,
		rst_i          => sys_rst_w,
		mmio_write_i   => mmio_write_w,
		wdata_i        => mmio_wdata_w,
		cs_btctl1_i    => cs_btctl1_w,
		cs_btctl2_i    => cs_btctl2_w,
		cs_btcmpr0_i   => cs_btcmpr0_w,
		cs_btcmpr1_i   => cs_btcmpr1_w,
		capin1_i       => CAPIN1_i,
		capin2_i       => CAPIN2_i,
		pwmout_o       => PWMout_o,
		btctl1_o       => btctl1_w,
		btctl2_o       => btctl2_w,
		btcmpr0_o      => btcmpr0_w,
		btcmpr1_o      => btcmpr1_w,
		btcapr_o       => btcapr_w,
		timer_event_o  => interrupt_event_w(2)
	);
	interrupt_event_w(3) <= pb_press_pulse_w(1); -- KEY1
	interrupt_event_w(4) <= pb_press_pulse_w(2); -- KEY2
	interrupt_event_w(5) <= pb_press_pulse_w(3); -- KEY3
	interrupt_event_w(6) <= '0';                 -- reserved

	int_ctrl: interrupt_controller
	PORT MAP (
		clk_i             => mclk_w,
		rst_i             => sys_rst_w,
		inta_n_i          => inta_n_w,
		irq_service_pulse_i => irq_service_pulse_w,
		irq_service_type_i  => irq_service_type_w,
		event_i           => interrupt_event_w,
		mmio_write_i      => mmio_write_w,
		cs_ie_i           => cs_ie_w,
		cs_ifg_i          => cs_ifg_w,
		wdata_i           => mmio_wdata_w(7 DOWNTO 0),
		ie_rdata_o        => ie_rdata_w,
		ifg_rdata_o       => ifg_rdata_w,
		type_rdata_o      => type_rdata_w,
		irq_pending_raw_o => irq_pending_raw_w
	);

END structural;
