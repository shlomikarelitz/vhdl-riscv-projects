--============================================================================
-- Copyright 2026 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Top Level Structural Model for Single-Cycle RISC-V Core
--============================================================================ 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.cond_compilation_package.all;
USE work.aux_package.all;


ENTITY RV32I_CORE IS
	generic( 
			G_HAS_DIVIDER       : boolean   := false;
			ITCM_INIT_FILE 		: string 	:= "ITCM.hex";
			DTCM_INIT_FILE 		: string 	:= "DTCM.hex";
			WORD_GRANULARITY 	: boolean 	:= G_WORD_GRANULARITY;
			DATA_BUS_WIDTH 		: integer 	:= 32;
			ITCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			DTCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			PC_WIDTH 					: integer 	:= G_PC_WIDTH;
			MA_WIDTH 					: integer 	:= G_MA_WIDTH;
			DATA_WORDS_NUM 		: integer 	:= G_DATA_WORDSNUM;
			CLK_CNT_WIDTH 		: integer 	:= 16
	);
	PORT(	
		--Inputs
		rst_i		 					:IN	STD_LOGIC;
		clk_i							:IN	STD_LOGIC;
		irq_pending_raw_i :IN STD_LOGIC;
		--Outputs (used also for Signal-Tap auxiliary pins)
		inta_n_o             : OUT STD_LOGIC;
		irq_service_pulse_o  : OUT STD_LOGIC;
		irq_service_type_o   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		pc_o							:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		RegWrite_ctrl_o		:OUT 	STD_LOGIC;
		MemWrite_ctrl_o		:OUT 	STD_LOGIC;
		Branch_ctrl_o			:OUT 	STD_LOGIC;
		
		read_data1_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		write_data_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		alu_res_o 				:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);															
		brTaken_o					:OUT 	STD_LOGIC; 
		
 		dtcm_addr_o				:OUT 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
		dtcm_data_wr_o		:OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_data_rd_o		:OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		-- MMIO Interface
		data_addr_o     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		data_wdata_o    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		data_rdata_i    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		data_read_o     : OUT STD_LOGIC;
		data_write_o    : OUT STD_LOGIC;
		data_funct3_o   : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		
		mclk_cnt_o				:OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
		-- Debug Signals
		dbg_dtcm_we_o   : OUT STD_LOGIC;
		dbg_mmio_we_o   : OUT STD_LOGIC;
		
		-- Divider handshake
		div_req_o        : OUT STD_LOGIC;
		div_ack_i        : IN  STD_LOGIC := '0';
		div_dividend_o   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		div_divisor_o    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		div_quotient_i   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
		div_remainder_i  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0')
	);		
END RV32I_CORE;
--============================================================================
ARCHITECTURE structure OF RV32I_CORE IS
	-- declare signals used to connect VHDL components
	SIGNAL pc_w 					: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL read_data1_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL read_data2_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL sign_extend_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL addr_gen_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL alu_res_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL dtcm_data_rd_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL alu_src_w 			: STD_LOGIC;
	SIGNAL branch_w 			: STD_LOGIC;
	SIGNAL Jal_ctrl_w 		: STD_LOGIC;
	SIGNAL Jalr_ctrl_w 		: STD_LOGIC;
	SIGNAL reg_write_w 		: STD_LOGIC;
	SIGNAL reg_dst_w 			: STD_LOGIC;
	SIGNAL brTaken_w 			: STD_LOGIC;
	SIGNAL mem_write_w 		: STD_LOGIC;
	SIGNAL MemtoReg_w 		: STD_LOGIC;
	SIGNAL mem_read_w 		: STD_LOGIC;
	SIGNAL upper_im_w			: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL alu_op_w 			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	
	SIGNAL funct3_w       : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL dtcm_sel_w     : STD_LOGIC;
	SIGNAL mmio_sel_w     : STD_LOGIC;
	SIGNAL dtcm_read_w    : STD_LOGIC;
	SIGNAL dtcm_write_w   : STD_LOGIC;
	SIGNAL mmio_read_w    : STD_LOGIC;
	SIGNAL mmio_write_w   : STD_LOGIC;
	SIGNAL dtcm_byteena_w : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL dtcm_wdata_w   : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL load_data_w    : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL instruction_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mclk_w 				: STD_LOGIC;
	SIGNAL mclk_cnt_q			: STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
	SIGNAL rst_internal  		: STD_LOGIC;
	
	-- Divider Signals
	SIGNAL div_pc_hold_w        : STD_LOGIC := '0';
	SIGNAL div_stall_w          : STD_LOGIC := '0';
	SIGNAL div_active_w         : STD_LOGIC := '0';
	SIGNAL div_result_to_wb_w   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
	SIGNAL is_div_instr_decoded_w : STD_LOGIC := '0';
	SIGNAL div_instruction_reg    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
	SIGNAL effective_instruction_w: STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
	SIGNAL div_active_q           : STD_LOGIC := '0';
	SIGNAL div_ctrl_instruction_w : STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
	SIGNAL div_start_w            : STD_LOGIC := '0';
	
	SIGNAL irq_suppress_normal_w: STD_LOGIC := '0';
	SIGNAL effective_pc_hold_w  : STD_LOGIC := '0';
	SIGNAL alu_res_from_exe_w   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
	
	SIGNAL normal_next_pc_w  : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL gie_w             : STD_LOGIC;
	SIGNAL irq_take_now_w    : STD_LOGIC;
	SIGNAL irq_accept_pulse_w: STD_LOGIC;
	SIGNAL suppress_normal_w : STD_LOGIC := '0';
	SIGNAL force_type_address_w : STD_LOGIC;
	SIGNAL force_vector_address_w : STD_LOGIC;
	SIGNAL pc_hold_w         : STD_LOGIC;
	SIGNAL pc_force_en_w     : STD_LOGIC;
	SIGNAL pc_force_value_w  : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL force_tp_write_w  : STD_LOGIC;
	SIGNAL force_tp_data_w   : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL service_pulse_w   : STD_LOGIC;
	SIGNAL irq_service_type_w: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL effective_data_addr_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL effective_reg_write_w : STD_LOGIC;
	SIGNAL effective_dtcm_byteena_w : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL effective_mmio_write_w : STD_LOGIC;
	SIGNAL reti_detect_w     : STD_LOGIC;
	SIGNAL normal_execute_w  : STD_LOGIC;
	SIGNAL effective_mem_read_w : STD_LOGIC;
	SIGNAL effective_mem_write_w: STD_LOGIC;
	
	
		--=========================================
	-- Debug / SignalTap preservation attributes
	-- Keep important internal signals with readable names
	--=========================================
	attribute keep     : boolean;
	attribute preserve : boolean;
	attribute noprune  : boolean;

	attribute keep of pc_w             : signal is true;
	attribute keep of pc_plus4_w       : signal is true;
	attribute keep of instruction_w    : signal is true;

	attribute keep of read_data1_w     : signal is true;
	attribute keep of read_data2_w     : signal is true;
	attribute keep of sign_extend_w    : signal is true;
	attribute keep of addr_gen_w       : signal is true;

	attribute keep of alu_res_w        : signal is true;
	attribute keep of dtcm_data_rd_w   : signal is true;

	attribute keep of alu_src_w        : signal is true;
	attribute keep of branch_w         : signal is true;
	attribute keep of Jal_ctrl_w       : signal is true;
	attribute keep of Jalr_ctrl_w      : signal is true;
	attribute keep of reg_write_w      : signal is true;
	attribute keep of reg_dst_w        : signal is true;
	attribute keep of brTaken_w        : signal is true;
	attribute keep of mem_write_w      : signal is true;
	attribute keep of MemtoReg_w       : signal is true;
	attribute keep of mem_read_w       : signal is true;
	attribute keep of upper_im_w       : signal is true;
	attribute keep of alu_op_w         : signal is true;

	attribute keep of mclk_w           : signal is true;
	attribute keep of mclk_cnt_q       : signal is true;

	attribute preserve of mclk_cnt_q   : signal is true;
	attribute noprune of mclk_cnt_q    : signal is true;

	SIGNAL pc_padded_w : STD_LOGIC_VECTOR(31 DOWNTO 0);

BEGIN
	-- Phase 3: Direct clock and internal active-high reset from external clock_reset_manager
	-- The top-level uses clock_reset_manager. We just pass through clk_i to mclk_w
	-- and rst_i directly to rst_internal since the external manager handles it.
	mclk_w       <= clk_i;
	rst_internal <= rst_i;
	
	pc_padded_w(PC_WIDTH-1 DOWNTO 0) <= pc_w;
	pc_padded_w(31 DOWNTO PC_WIDTH)  <= (others => '0');
	
	-- Note: pc_w represents the word address within the instruction memory (ITCM) in this baseline,
	-- so it counts in words (0, 1, 2, 3...) rather than byte addresses.
	-- If architectural byte PC is required for LSU, it should be shifted left by 2:
	-- pc_padded_w <= EXT(pc_w & "00", 32);
	-- For now we just pad pc_w directly to match the expected load_store_unit port.
	
	normal_execute_w <= '1' when suppress_normal_w = '0' else '0';
	effective_data_addr_w <= x"0000202E" when force_type_address_w = '1' else (x"000000" & irq_service_type_w) when force_vector_address_w = '1' else alu_res_w;
	effective_reg_write_w <= reg_write_w and not suppress_normal_w;
	effective_mem_write_w <= mem_write_w and not suppress_normal_w;
	effective_mmio_write_w <= mmio_write_w and not suppress_normal_w;
	effective_dtcm_byteena_w <= dtcm_byteena_w when suppress_normal_w = '0' else "0000";
	effective_mem_read_w <= '1' when (force_type_address_w = '1' or force_vector_address_w = '1') else (mem_read_w and not suppress_normal_w);
	
	--=======================================
	-- Interrupt Entry Controller
	--=======================================
	INT_ENTRY: entity work.interrupt_entry_controller
	generic map(
		PC_WIDTH => PC_WIDTH,
		DATA_BUS_WIDTH => DATA_BUS_WIDTH
	)
	port map(
		clk_i => mclk_w,
		rst_i => rst_internal,
		irq_pending_raw_i => irq_pending_raw_i,
		gie_i => gie_w,
		normal_next_pc_i => normal_next_pc_w,
		-- The first entry cycle reads TYPE from MMIO; the second reads
		-- Mem[TYPE] from DTCM.  load_data_w is the unified LSU result.
		data_bus_rdata_i => load_data_w,
		irq_take_now_o => irq_take_now_w,
		irq_accept_pulse_o => irq_accept_pulse_w,
		inta_n_o => inta_n_o,
		force_type_address_o => force_type_address_w,
		force_vector_address_o => force_vector_address_w,
		suppress_normal_side_effects_o => irq_suppress_normal_w,
		pc_hold_o => pc_hold_w,
		pc_force_en_o => pc_force_en_w,
		pc_force_value_o => pc_force_value_w,
		force_tp_write_o => force_tp_write_w,
		force_tp_data_o => force_tp_data_w,
		irq_service_pulse_o => irq_service_pulse_o,
		irq_service_type_o => irq_service_type_w,
		state_debug_o => open,
		divider_active_i => div_active_w
	);
	
	suppress_normal_w <= irq_suppress_normal_w or div_stall_w;
	effective_pc_hold_w <= pc_hold_w or div_pc_hold_w;
	
	DIV_INSTRUCTION_STATE : entity work.divider_instruction_latch
	port map (
		clk_i                 => mclk_w,
		rst_i                 => rst_internal,
		div_start_i           => div_start_w,
		div_active_i          => div_active_w,
		fetched_instruction_i => instruction_w,
		div_active_delayed_o  => div_active_q,
		held_instruction_o    => div_instruction_reg
	);
	
	effective_instruction_w <= (others => '0') when irq_suppress_normal_w = '1' else
	                           div_instruction_reg when (div_active_w = '1' and div_active_q = '1' and div_start_w = '0') else
	                           instruction_w;
	
	div_ctrl_instruction_w <= (others => '0') when irq_suppress_normal_w = '1' else instruction_w;
	
	--===========================================
	-- IFETCH (including ITCM) module connection
	--===========================================
	IFE : Ifetch
	generic map(
		ITCM_INIT_FILE		=> ITCM_INIT_FILE,
		WORD_GRANULARITY	=> 	WORD_GRANULARITY,
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH, 
		PC_WIDTH					=>	PC_WIDTH,
		ITCM_ADDR_WIDTH		=>	ITCM_ADDR_WIDTH,
		WORDS_NUM					=>	DATA_WORDS_NUM
	)
	PORT MAP (
		--Inputs
		clk_i 					=> mclk_w,  
		rst_i 					=> rst_internal, 
		addr_gen_i 			=> addr_gen_w,
		Branch_ctrl_i 	=> branch_w,
		brTaken_i				=> brTaken_w,
		Jal_ctrl_i 			=> Jal_ctrl_w,
		Jalr_ctrl_i			=> Jalr_ctrl_w,
		alu_res_i				=> alu_res_w,
		pc_hold_i       => effective_pc_hold_w,
		pc_force_en_i   => pc_force_en_w,
		pc_force_value_i=> pc_force_value_w,
		
		--Outputs
		normal_next_pc_o=> normal_next_pc_w,
		pc_o 						=> pc_w,
		pc_plus4_o	 		=> pc_plus4_w,
		instruction_o 	=> instruction_w    
	);
	--=======================================
	-- IDECODE module connection
	--=======================================
	ID : Idecode
  generic map(
		PC_WIDTH				=>	PC_WIDTH,
		DATA_BUS_WIDTH	=>  DATA_BUS_WIDTH
	)
	PORT MAP (	
		--Inputs
		clk_i 					=> mclk_w,  
		rst_i 					=> rst_internal,
		pc_plus4_i	 		=> pc_plus4_w,
    instruction_i 	=> effective_instruction_w,
    dtcm_data_rd_i 	=> load_data_w,
		alu_res_i 			=> alu_res_w,
		RegDst_ctrl_i		=> reg_dst_w,
		RegWrite_ctrl_i => reg_write_w,
		MemtoReg_ctrl_i => MemtoReg_w,
		irq_take_now_i  => irq_take_now_w,
		normal_execute_i=> normal_execute_w,
		force_tp_write_i=> force_tp_write_w,
		force_tp_data_i => force_tp_data_w,
		
		--Outputs
		gie_o           => gie_w,
		reti_detect_o   => reti_detect_w,
		read_data1_o 		=> read_data1_w,
    read_data2_o 		=> read_data2_w,
		SignExt_o 			=> sign_extend_w	 
	);
	--=======================================
	-- CONTROL module connection
	--=======================================
	CTL:   control
	PORT MAP ( 	
		--Inputs
		instruction_i 		=> effective_instruction_w,
		
		--Outputs
		RegDst_ctrl_o			=> reg_dst_w,
		ALUSrc_ctrl_o 		=> alu_src_w,
		MemtoReg_ctrl_o 	=> MemtoReg_w,
		RegWrite_ctrl_o 	=> reg_write_w,
		MemRead_ctrl_o 		=> mem_read_w,
		MemWrite_ctrl_o 	=> mem_write_w,
		Branch_ctrl_o 		=> branch_w,
		Jal_ctrl_o 				=> Jal_ctrl_w,
		Jalr_ctrl_o				=> Jalr_ctrl_w,
		UpperIm_ctrl_o 		=> upper_im_w,
		ALUOp_ctrl_o 			=> alu_op_w
	);
	--=======================================
	-- EXECUTE module connection
	--=======================================
	EXE:  Execute
  generic map(
		DATA_BUS_WIDTH 	=> 	DATA_BUS_WIDTH,
		PC_WIDTH 				=>	PC_WIDTH
	)
	PORT MAP (	
		--Inputs
		read_data1_i 		=> read_data1_w,
    read_data2_i 		=> read_data2_w,
		sign_extend_i 	=> sign_extend_w,
		UpperIm_ctrl_i 	=> upper_im_w,
		ALUOp_ctrl_i 		=> alu_op_w,
		ALUSrc_ctrl_i 	=> alu_src_w,
		pc_i						=> pc_w,
		
		--Outputs
		brTaken_o 			=> brTaken_w,
    alu_res_o				=> alu_res_from_exe_w,
		addr_gen_o 			=> addr_gen_w			
	);
	
	alu_res_w <= div_result_to_wb_w WHEN div_active_w = '1' ELSE alu_res_from_exe_w;
	--=======================================
	-- DTCM module connection
	--=======================================
	funct3_w <= "010" when force_vector_address_w = '1' else "100" when force_type_address_w = '1' else effective_instruction_w(14 DOWNTO 12);
	
	BUS_ROUTER: data_address_router
	PORT MAP (
		data_addr_i     => effective_data_addr_w,
		mem_read_i      => effective_mem_read_w,
		mem_write_i     => effective_mem_write_w,
		dtcm_sel_o      => dtcm_sel_w,
		dtcm_read_o     => dtcm_read_w,
		dtcm_write_o    => dtcm_write_w,
		mmio_sel_o      => mmio_sel_w,
		mmio_read_o     => mmio_read_w,
		mmio_write_o    => mmio_write_w
	);

	LSU: load_store_unit
	PORT MAP (
		data_addr_i     => effective_data_addr_w,
		data_wdata_i    => read_data2_w,
		funct3_i        => funct3_w,
		
		-- Diagnostics
		mem_read_i      => effective_mem_read_w,
		mem_write_i     => effective_mem_write_w,
		pc_i            => pc_padded_w,
		instruction_i   => effective_instruction_w,
		
		dtcm_rdata_i    => dtcm_data_rd_w,
		mmio_rdata_i    => data_rdata_i,
		mmio_sel_i      => mmio_sel_w,
		dtcm_byteena_o  => dtcm_byteena_w,
		dtcm_wdata_o    => dtcm_wdata_w,
		mmio_wdata_o    => data_wdata_o,
		load_data_o     => load_data_w
	);
	
	-- Connect Debug Signals
	dbg_dtcm_we_o <= dtcm_write_w and normal_execute_w;
	dbg_mmio_we_o <= effective_mmio_write_w;

	MEM:  dmemory
	generic map(
		DTCM_INIT_FILE		=> DTCM_INIT_FILE,
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH, 
		DTCM_ADDR_WIDTH		=> 	DTCM_ADDR_WIDTH,
		WORDS_NUM					=>	DATA_WORDS_NUM
	)
	PORT MAP (	
		--Inputs
		clk_i 						=> mclk_w,  
		rst_i 						=> rst_internal,
		dtcm_addr_i 			=> effective_data_addr_w(13 DOWNTO 0),
		dtcm_data_wr_i 		=> dtcm_wdata_w,
		byteena_i         => effective_dtcm_byteena_w,
		MemRead_ctrl_i 		=> dtcm_read_w, 
		MemWrite_ctrl_i 	=> dtcm_write_w,
				
		--Outputs
		dtcm_data_rd_o 		=> dtcm_data_rd_w 
	);	
	
	--=======================================
	-- MCLK counter register connection
	--=======================================									
	MCLK_CNT_INST : entity work.mclk_counter
	generic map (
		CLK_CNT_WIDTH => CLK_CNT_WIDTH
	)
	port map (
		clk_i      => mclk_w,
		rst_i      => rst_internal,
		mclk_cnt_o => mclk_cnt_q
	);

	--=======================================
	-- Divider Controller Instantiation
	--=======================================									
	DIV_CTRL_INST : entity work.divider_controller
	generic map (
		G_HAS_DIVIDER => G_HAS_DIVIDER
	)
	port map (
		clk_i               => mclk_w,
		rst_i               => rst_internal,
		instruction_i       => div_ctrl_instruction_w,
		rs1_data_i          => read_data1_w,
		rs2_data_i          => read_data2_w,
		
		ack_divclk_i        => div_ack_i,
		quotient_divclk_i   => div_quotient_i,
		remainder_divclk_i  => div_remainder_i,
		
		req_divclk_o        => div_req_o,
		dividend_o          => div_dividend_o,
		divisor_o           => div_divisor_o,
		result_o            => div_result_to_wb_w,
		
		pc_hold_o           => div_pc_hold_w,
		divider_stall_o     => div_stall_w,
		active_o            => div_active_w,
		is_div_instr_o      => is_div_instr_decoded_w,
		div_start_o         => div_start_w
	);
---------------------------------------------------------------------------------------
-- Copying out important signals only for Verification and FPGA Velidation(Signal-TAP)
---------------------------------------------------------------------------------------
	pc_o							<=	pc_w;																				-- IFETCH output								
  instruction_o 		<= 	instruction_w;															-- IFETCH output
	
	RegWrite_ctrl_o 	<= 	reg_write_w;																-- CONTROL output
  MemWrite_ctrl_o 	<= 	mem_write_w;																-- CONTROL output
	Branch_ctrl_o 		<= 	branch_w;																		-- CONTROL output
	  
  read_data1_o 			<= 	read_data1_w;																-- IDECODE output
  read_data2_o 			<= 	read_data2_w;																-- IDECODE output
  write_data_o  		<= 	load_data_w WHEN MemtoReg_w = '1' ELSE		-- IDECODE input(Write-Back) 
												alu_res_w;
												
  alu_res_o 				<= 	alu_res_w;																	-- EXECUTE output			
  brTaken_o 				<= 	brTaken_w;																	-- EXECUTE output
  
	dtcm_addr_o 			<= 	effective_data_addr_w(DTCM_ADDR_WIDTH-1 DOWNTO 0);																-- DMEMORY input
	dtcm_data_wr_o 		<= 	dtcm_wdata_w;																-- DMEMORY input
	dtcm_data_rd_o		<=	dtcm_data_rd_w;															-- DMEMORY output
	
	-- MMIO
	data_addr_o     <= effective_data_addr_w;
	data_read_o     <= mmio_read_w;
	data_write_o    <= effective_mmio_write_w;
	data_funct3_o   <= funct3_w;
	irq_service_type_o <= irq_service_type_w;

	
	mclk_cnt_o				<=	mclk_cnt_q;																	-- TOP output
	
---------------------------------------------------------------------------------------

END structure;


