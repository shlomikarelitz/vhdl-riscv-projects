LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

LIBRARY work;
USE work.cond_compilation_package.all;

ENTITY RV32IM_CORE_pipeline IS
	GENERIC (
		PC_WIDTH 			: integer := G_PC_WIDTH;
		MA_WIDTH 			: integer := G_MA_WIDTH;
		DATA_WORDS_NUM 		: integer := G_DATA_WORDSNUM;
		ITCM_ADDR_WIDTH 	: integer := G_ADDRWIDTH;
		DTCM_ADDR_WIDTH 	: integer := G_ADDRWIDTH;
		ITCM_INIT_FILE 		: string  := "programs/rt5/ITCM.hex";
		DTCM_INIT_FILE 		: string  := "programs/rt5/DTCM.hex"
	);
	PORT (
		clk_i 			: IN  STD_LOGIC;
		rst_i 			: IN  STD_LOGIC;
		BPADDR_i 		: IN  STD_LOGIC_VECTOR(7 DOWNTO 0);

		CLKCNT_o 		: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		IFpc_o 			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IFinstruction_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		IDpc_o 			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IDinstruction_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		EXpc_o 			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EXinstruction_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		MEMpc_o 		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEMinstruction_o: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		WBpc_o 			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		WBinstruction_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		-- DTCM Monitoring (for TB)
		dtcm_addr_o		: OUT STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
		dtcm_data_wr_o	: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		MemWrite_ctrl_o	: OUT STD_LOGIC;

		-- Pipeline counters
		STRIGGER_o 		: OUT STD_LOGIC;
		FHCNT_o 		: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		STCNT_o 		: OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END RV32IM_CORE_pipeline;

ARCHITECTURE behavior OF RV32IM_CORE_pipeline IS
	SIGNAL mclk_w 			: STD_LOGIC;
	
	-- IF Stage
	SIGNAL IF_pc_w 			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL IF_pc_plus4_w 	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL IF_instruction_w : STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	-- ID Stage
	SIGNAL ID_pc_w 			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ID_pc_plus4_w 	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ID_instruction_w : STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	SIGNAL ID_RegDst_ctrl_w		: STD_LOGIC;
	SIGNAL ID_ALUSrc_ctrl_w 	: STD_LOGIC;
	SIGNAL ID_MemtoReg_ctrl_w 	: STD_LOGIC;
	SIGNAL ID_RegWrite_ctrl_w 	: STD_LOGIC;
	SIGNAL ID_MemRead_ctrl_w 	: STD_LOGIC;
	SIGNAL ID_MemWrite_ctrl_w 	: STD_LOGIC;
	SIGNAL ID_Branch_ctrl_w 	: STD_LOGIC;
	SIGNAL ID_Jal_ctrl_w 		: STD_LOGIC;
	SIGNAL ID_Jalr_ctrl_w		: STD_LOGIC;
	SIGNAL ID_UpperIm_ctrl_w 	: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL ID_ALUOp_ctrl_w 		: STD_LOGIC_VECTOR(4 DOWNTO 0);

	SIGNAL ID_read_data1_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL ID_read_data2_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL ID_SignExt_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL ID_rs1_w 		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL ID_rs2_w 		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL ID_rd_w 			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	
	-- EX Stage Inputs
	SIGNAL EX_pc_w 			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL EX_pc_plus4_w 	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL EX_instruction_w : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL EX_read_data1_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL EX_read_data2_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL EX_SignExt_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL EX_rs1_w 		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL EX_rs2_w 		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL EX_rd_w 			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	
	SIGNAL EX_RegDst_ctrl_w		: STD_LOGIC;
	SIGNAL EX_ALUSrc_ctrl_w 	: STD_LOGIC;
	SIGNAL EX_MemtoReg_ctrl_w 	: STD_LOGIC;
	SIGNAL EX_RegWrite_ctrl_w 	: STD_LOGIC;
	SIGNAL EX_MemRead_ctrl_w 	: STD_LOGIC;
	SIGNAL EX_MemWrite_ctrl_w 	: STD_LOGIC;
	SIGNAL EX_Branch_ctrl_w 	: STD_LOGIC;
	SIGNAL EX_Jal_ctrl_w 		: STD_LOGIC;
	SIGNAL EX_Jalr_ctrl_w		: STD_LOGIC;
	SIGNAL EX_UpperIm_ctrl_w 	: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL EX_ALUOp_ctrl_w 		: STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- EX Stage Outputs
	SIGNAL EX_BrTaken_w 	: STD_LOGIC;
	SIGNAL EX_ALURes_w 		: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL EX_BranchTarget_w: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL EX_P0_w 			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EX_P1_w 			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EX_P2_w 			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EX_P3_w 			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EX_IsMul_w 		: STD_LOGIC;

	-- MEM Stage Signals
	SIGNAL MEM_pc_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL MEM_pc_plus4_w 	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL MEM_instruction_w: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL MEM_ALURes_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL MEM_BrTaken_w 	: STD_LOGIC;
	SIGNAL MEM_BranchTarget_w : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL MEM_rd_w 		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL MEM_WriteData_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	SIGNAL MEM_P0_w 		: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL MEM_P1_w 		: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL MEM_P2_w 		: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL MEM_P3_w 		: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL MEM_IsMul_w 		: STD_LOGIC;

	-- Data memory output signal
	SIGNAL MEM_dtcm_addr_w 		: STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);

	SIGNAL MEM_RegDst_ctrl_w	: STD_LOGIC;
	SIGNAL MEM_MemtoReg_ctrl_w 	: STD_LOGIC;
	SIGNAL MEM_RegWrite_ctrl_w 	: STD_LOGIC;
	SIGNAL MEM_MemRead_ctrl_w 	: STD_LOGIC;
	SIGNAL MEM_MemWrite_ctrl_w 	: STD_LOGIC;
	SIGNAL MEM_Branch_ctrl_w 	: STD_LOGIC;
	SIGNAL MEM_Jal_ctrl_w 		: STD_LOGIC;
	SIGNAL MEM_Jalr_ctrl_w		: STD_LOGIC;
	
	SIGNAL MEM_MemData_w 		: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL MEM_ExecResult_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	

	-- WB Stage Signals
	SIGNAL WB_pc_w 			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL WB_pc_plus4_w 	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL WB_instruction_w : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL WB_ExecResult_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL WB_MemData_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL WB_rd_w 			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL WB_write_data_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	SIGNAL WB_RegDst_ctrl_w		: STD_LOGIC;
	SIGNAL WB_MemtoReg_ctrl_w 	: STD_LOGIC;
	SIGNAL WB_RegWrite_ctrl_w 	: STD_LOGIC;
	
	-- Forwarding Unit Signals
	SIGNAL ForwardA_w 			: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL ForwardB_w 			: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL EX_operandA_fwd_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL EX_operandB_fwd_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL EX_store_data_fwd_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL MEM_forward_value_w 	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	
	SIGNAL STCNT_Enable_w 		: STD_LOGIC;
	SIGNAL STCNT_q 				: STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
	
	SIGNAL PC_WriteEnable_stall : STD_LOGIC;
	SIGNAL IF_ID_WriteEnable_stall : STD_LOGIC;
	SIGNAL ID_EX_Bubble_stall 	: STD_LOGIC;
	SIGNAL STCNT_Enable_stall 	: STD_LOGIC;
	
	SIGNAL CLKCNT_q 			: STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
	SIGNAL FHCNT_q 				: STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
	
	-- Pipeline Controls and Redirects
	SIGNAL PC_WriteEnable_w : STD_LOGIC;
	SIGNAL IF_ID_WriteEnable_w : STD_LOGIC;
	SIGNAL redirect_valid_w : STD_LOGIC;
	SIGNAL redirect_target_w: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL IF_ID_Flush_w 	: STD_LOGIC;
	SIGNAL ID_EX_Bubble_w 	: STD_LOGIC;
	SIGNAL ID_EX_Flush_w 	: STD_LOGIC;
	SIGNAL EX_MEM_Flush_w 	: STD_LOGIC;
	
	-- Mocking WB write data for step 5 testing
	SIGNAL mock_redirect_valid_w : STD_LOGIC := '0';
	SIGNAL mock_redirect_target_w: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0) := (others => '0');

	SIGNAL pll_locked_internal : STD_LOGIC;
	SIGNAL rst_req_async : STD_LOGIC;
	SIGNAL rst_sync_1    : STD_LOGIC := '1';
	SIGNAL rst_sync_2    : STD_LOGIC := '1';
	SIGNAL rst_internal  : STD_LOGIC;
	SIGNAL pll_locked_w  : STD_LOGIC;

	attribute keep : boolean;
	attribute keep of IF_pc_w, IF_instruction_w : signal is true;
	attribute keep of ID_pc_w, ID_instruction_w : signal is true;
	attribute keep of EX_pc_w, EX_instruction_w, EX_ALURes_w : signal is true;
	attribute keep of MEM_pc_w, MEM_instruction_w, MEM_ALURes_w, MEM_WriteData_w : signal is true;
	attribute keep of WB_pc_w, WB_instruction_w, WB_write_data_w : signal is true;
	attribute keep of rst_internal, pll_locked_w : signal is true;

	-- =========================================================
	-- SignalTap Aliases for Single-Cycle Compatibility
	-- =========================================================
	SIGNAL addr_gen_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL alu_op_w 		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL alu_src_w 		: STD_LOGIC;
	SIGNAL branch_w 		: STD_LOGIC;
	SIGNAL Jal_ctrl_w 		: STD_LOGIC;
	SIGNAL Jalr_ctrl_w		: STD_LOGIC;
	SIGNAL reg_write_w 		: STD_LOGIC;
	SIGNAL reg_dst_w 		: STD_LOGIC;
	SIGNAL brTaken_w 		: STD_LOGIC;
	SIGNAL mem_write_w 		: STD_LOGIC;
	SIGNAL MemtoReg_w 		: STD_LOGIC;
	SIGNAL mem_read_w 		: STD_LOGIC;
	SIGNAL upper_im_w 		: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL mclk_cnt_q       : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL write_data_o     : STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	attribute keep of addr_gen_w, alu_op_w, alu_src_w, branch_w : signal is true;
	attribute keep of Jal_ctrl_w, Jalr_ctrl_w, reg_write_w, reg_dst_w : signal is true;
	attribute keep of brTaken_w, mem_write_w, MemtoReg_w, mem_read_w, upper_im_w : signal is true;
	attribute keep of mclk_cnt_q, write_data_o : signal is true;

BEGIN

	-- In ModelSim, PLL is bypassed so locked is always 1
	-- On FPGA, rst_req_async is active if button pressed OR PLL not locked
	pll_locked_w <= '1' WHEN G_MODELSIM = 1 ELSE pll_locked_internal;
	rst_req_async <= rst_i WHEN G_MODELSIM = 1 ELSE (not rst_i) OR (not pll_locked_w);

	-- =========================================================
	-- SignalTap Aliases Assignments
	-- =========================================================
	addr_gen_w  <= EX_BranchTarget_w;
	alu_op_w    <= ID_ALUOp_ctrl_w;
	alu_src_w   <= ID_ALUSrc_ctrl_w;
	branch_w    <= ID_Branch_ctrl_w;
	Jal_ctrl_w  <= ID_Jal_ctrl_w;
	Jalr_ctrl_w <= ID_Jalr_ctrl_w;
	reg_write_w <= WB_RegWrite_ctrl_w;
	reg_dst_w   <= WB_RegDst_ctrl_w;
	brTaken_w   <= EX_BrTaken_w;
	mem_write_w <= MEM_MemWrite_ctrl_w;
	MemtoReg_w  <= WB_MemtoReg_ctrl_w;
	mem_read_w  <= MEM_MemRead_ctrl_w;
	upper_im_w  <= ID_UpperIm_ctrl_w;
	mclk_cnt_q  <= CLKCNT_q(15 DOWNTO 0);
	write_data_o <= WB_write_data_w;

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

	rst_internal <= rst_sync_2;

	G1: 
	IF (G_MODELSIM = 0) GENERATE
		inst_PLL: entity work.PLL
		PORT MAP (
			inclk0   => clk_i,
			c0       => mclk_w,
			locked   => pll_locked_internal
		);
	ELSIF (G_MODELSIM = 1) GENERATE
		mclk_w <= clk_i;
	END GENERATE;
	
	-------------------------------------------------------------------------
	-- PIPELINE CONTROLS & FLUSH LOGIC
	-------------------------------------------------------------------------
	IF_ID_Flush_w  <= redirect_valid_w;
	ID_EX_Flush_w  <= redirect_valid_w;
	EX_MEM_Flush_w <= redirect_valid_w;

	-- Effective stall controls: Flush overrides Stall
	PC_WriteEnable_w    <= '1' WHEN redirect_valid_w = '1' ELSE PC_WriteEnable_stall;
	IF_ID_WriteEnable_w <= '1' WHEN redirect_valid_w = '1' ELSE IF_ID_WriteEnable_stall;
	ID_EX_Bubble_w      <= '0' WHEN redirect_valid_w = '1' ELSE ID_EX_Bubble_stall;
	STCNT_Enable_w      <= '0' WHEN redirect_valid_w = '1' ELSE STCNT_Enable_stall;

	-------------------------------------------------------------------------
	-- STAGE 1: INSTRUCTION FETCH
	-------------------------------------------------------------------------
	inst_IFETCH: entity work.Ifetch_pipeline
	GENERIC MAP (
		WORD_GRANULARITY 	=> G_WORD_GRANULARITY,
		DATA_BUS_WIDTH 		=> 32,
		PC_WIDTH 			=> PC_WIDTH,
		ITCM_ADDR_WIDTH 	=> ITCM_ADDR_WIDTH,
		WORDS_NUM 			=> DATA_WORDS_NUM,
		ITCM_INIT_FILE 		=> ITCM_INIT_FILE
	)
	PORT MAP (
		clk_i				=> mclk_w,
		rst_i 				=> rst_internal,
		PC_WriteEnable_i 	=> PC_WriteEnable_w,
		redirect_valid_i 	=> redirect_valid_w,
		redirect_target_i 	=> redirect_target_w,
		pc_o 				=> IF_pc_w,
		pc_plus4_o 			=> IF_pc_plus4_w,
		instruction_o 		=> IF_instruction_w
	);

	-------------------------------------------------------------------------
	-- IF/ID PIPELINE REGISTER
	-------------------------------------------------------------------------
	inst_IF_ID_REG: entity work.IF_ID_REG
	GENERIC MAP (
		PC_WIDTH 		=> PC_WIDTH,
		DATA_BUS_WIDTH 	=> 32
	)
	PORT MAP (
		clk_i 				=> mclk_w,
		rst_i 				=> rst_internal,
		IF_ID_WriteEnable_i => IF_ID_WriteEnable_w,
		Flush_i 			=> IF_ID_Flush_w,
		IF_PC_i 			=> IF_pc_w,
		IF_PC_PLUS4_i 		=> IF_pc_plus4_w,
		IF_Instruction_i 	=> IF_instruction_w,
		ID_PC_o 			=> ID_pc_w,
		ID_PC_PLUS4_o 		=> ID_pc_plus4_w,
		ID_Instruction_o 	=> ID_instruction_w
	);

	-------------------------------------------------------------------------
	-- STAGE 2: IDECODE & CONTROL
	-------------------------------------------------------------------------
	-- WB feedback mock for step 5 testing
	-- we'll feed back the actual WB signals! This is safe because WB_RegWrite_w acts accordingly
	
	inst_IDECODE: entity work.Idecode_pipeline
	GENERIC MAP (
		DATA_BUS_WIDTH 	=> 32
	)
	PORT MAP (
		clk_i 			=> mclk_w,
		rst_i 			=> rst_internal,
		instruction_i 	=> ID_instruction_w,
		WB_rd_i 		=> WB_rd_w,
		WB_write_data_i => WB_write_data_w,
		WB_RegWrite_i 	=> WB_RegWrite_ctrl_w,
		rs1_o 			=> ID_rs1_w,
		rs2_o 			=> ID_rs2_w,
		rd_o 			=> ID_rd_w,
		read_data1_o 	=> ID_read_data1_w,
		read_data2_o 	=> ID_read_data2_w,
		SignExt_o 		=> ID_SignExt_w
	);

	inst_CONTROL: entity work.control
	PORT MAP (
		instruction_i 	=> ID_instruction_w,
		RegDst_ctrl_o	=> ID_RegDst_ctrl_w,
		ALUSrc_ctrl_o 	=> ID_ALUSrc_ctrl_w,
		MemtoReg_ctrl_o => ID_MemtoReg_ctrl_w,
		RegWrite_ctrl_o => ID_RegWrite_ctrl_w,
		MemRead_ctrl_o 	=> ID_MemRead_ctrl_w,
		MemWrite_ctrl_o => ID_MemWrite_ctrl_w,
		Branch_ctrl_o 	=> ID_Branch_ctrl_w,
		Jal_ctrl_o 		=> ID_Jal_ctrl_w,
		Jalr_ctrl_o		=> ID_Jalr_ctrl_w,
		UpperIm_ctrl_o 	=> ID_UpperIm_ctrl_w,
		ALUOp_ctrl_o 	=> ID_ALUOp_ctrl_w
	);

	-------------------------------------------------------------------------
	-- STALL UNIT
	-------------------------------------------------------------------------
	inst_STALL_UNIT: entity work.STALL_UNIT
	PORT MAP(
		ID_instruction_i 	=> ID_instruction_w,
		EX_rd_i 			=> EX_rd_w,
		EX_MemRead_i 		=> EX_MemRead_ctrl_w,
		PC_WriteEnable_o 	=> PC_WriteEnable_stall,
		IF_ID_WriteEnable_o => IF_ID_WriteEnable_stall,
		ID_EX_Bubble_o 		=> ID_EX_Bubble_stall,
		STCNT_Enable_o 		=> STCNT_Enable_stall
	);

	-------------------------------------------------------------------------
	-- ID/EX PIPELINE REGISTER
	-------------------------------------------------------------------------
	inst_ID_EX_REG: entity work.ID_EX_REG
	GENERIC MAP (
		PC_WIDTH 		=> PC_WIDTH,
		DATA_BUS_WIDTH 	=> 32
	)
	PORT MAP (
		clk_i 				=> mclk_w,
		rst_i 				=> rst_internal,
		Bubble_i 			=> ID_EX_Bubble_w,
		Flush_i 			=> ID_EX_Flush_w,
		ID_PC_i 			=> ID_pc_w,
		ID_PC_PLUS4_i 		=> ID_pc_plus4_w,
		ID_Instruction_i 	=> ID_instruction_w,
		read_data1_i 		=> ID_read_data1_w,
		read_data2_i 		=> ID_read_data2_w,
		SignExt_i 			=> ID_SignExt_w,
		rs1_i 				=> ID_rs1_w,
		rs2_i 				=> ID_rs2_w,
		rd_i 				=> ID_rd_w,
		RegDst_ctrl_i		=> ID_RegDst_ctrl_w,
		ALUSrc_ctrl_i 		=> ID_ALUSrc_ctrl_w,
		MemtoReg_ctrl_i 	=> ID_MemtoReg_ctrl_w,
		RegWrite_ctrl_i 	=> ID_RegWrite_ctrl_w,
		MemRead_ctrl_i 		=> ID_MemRead_ctrl_w,
		MemWrite_ctrl_i 	=> ID_MemWrite_ctrl_w,
		Branch_ctrl_i 		=> ID_Branch_ctrl_w,
		Jal_ctrl_i 			=> ID_Jal_ctrl_w,
		Jalr_ctrl_i			=> ID_Jalr_ctrl_w,
		UpperIm_ctrl_i 		=> ID_UpperIm_ctrl_w,
		ALUOp_ctrl_i 		=> ID_ALUOp_ctrl_w,
		
		EX_PC_o 			=> EX_pc_w,
		EX_PC_PLUS4_o 		=> EX_pc_plus4_w,
		EX_Instruction_o 	=> EX_instruction_w,
		EX_read_data1_o 	=> EX_read_data1_w,
		EX_read_data2_o 	=> EX_read_data2_w,
		EX_SignExt_o 		=> EX_SignExt_w,
		EX_rs1_o 			=> EX_rs1_w,
		EX_rs2_o 			=> EX_rs2_w,
		EX_rd_o 			=> EX_rd_w,
		EX_RegDst_ctrl_o	=> EX_RegDst_ctrl_w,
		EX_ALUSrc_ctrl_o 	=> EX_ALUSrc_ctrl_w,
		EX_MemtoReg_ctrl_o 	=> EX_MemtoReg_ctrl_w,
		EX_RegWrite_ctrl_o 	=> EX_RegWrite_ctrl_w,
		EX_MemRead_ctrl_o 	=> EX_MemRead_ctrl_w,
		EX_MemWrite_ctrl_o 	=> EX_MemWrite_ctrl_w,
		EX_Branch_ctrl_o 	=> EX_Branch_ctrl_w,
		EX_Jal_ctrl_o 		=> EX_Jal_ctrl_w,
		EX_Jalr_ctrl_o		=> EX_Jalr_ctrl_w,
		EX_UpperIm_ctrl_o 	=> EX_UpperIm_ctrl_w,
		EX_ALUOp_ctrl_o 	=> EX_ALUOp_ctrl_w
	);

	-------------------------------------------------------------------------
	-- FORWARDING UNIT & MULTIPLEXERS
	-------------------------------------------------------------------------
	inst_FORWARDING_UNIT: entity work.FORWARDING_UNIT
	PORT MAP(
		EX_rs1_i 		=> EX_rs1_w,
		EX_rs2_i 		=> EX_rs2_w,
		MEM_rd_i 		=> MEM_rd_w,
		MEM_RegWrite_i 	=> MEM_RegWrite_ctrl_w,
		MEM_MemtoReg_i 	=> MEM_MemtoReg_ctrl_w,
		WB_rd_i 		=> WB_rd_w,
		WB_RegWrite_i 	=> WB_RegWrite_ctrl_w,
		ForwardA_o 		=> ForwardA_w,
		ForwardB_o 		=> ForwardB_w
	);

	MEM_forward_value_w <= ( (31 DOWNTO PC_WIDTH => '0') & MEM_pc_plus4_w )
						   WHEN MEM_RegDst_ctrl_w = '1' ELSE
						   MEM_ExecResult_w;

	EX_operandA_fwd_w <= WB_write_data_w WHEN ForwardA_w = "10" ELSE
						 MEM_forward_value_w WHEN ForwardA_w = "01" ELSE
						 EX_read_data1_w;

	EX_operandB_fwd_w <= WB_write_data_w WHEN ForwardB_w = "10" ELSE
						 MEM_forward_value_w WHEN ForwardB_w = "01" ELSE
						 EX_read_data2_w;
						 
	EX_store_data_fwd_w <= EX_operandB_fwd_w;

	-------------------------------------------------------------------------
	-- STAGE 3: EXECUTE
	-------------------------------------------------------------------------
	inst_EXECUTE: entity work.Execute_pipeline
	GENERIC MAP (
		DATA_BUS_WIDTH 	=> 32,
		PC_WIDTH 		=> PC_WIDTH
	)
	PORT MAP (
		read_data1_i 	=> EX_operandA_fwd_w,
		read_data2_i 	=> EX_operandB_fwd_w,
		sign_extend_i 	=> EX_SignExt_w,
		UpperIm_ctrl_i 	=> EX_UpperIm_ctrl_w,
		ALUOp_ctrl_i 	=> EX_ALUOp_ctrl_w,
		ALUSrc_ctrl_i 	=> EX_ALUSrc_ctrl_w,
		pc_i 			=> EX_pc_w,
		brTaken_o 		=> EX_BrTaken_w,
		alu_res_o 		=> EX_ALURes_w,
		addr_gen_o 		=> EX_BranchTarget_w,
		P0_o 			=> EX_P0_w,
		P1_o 			=> EX_P1_w,
		P2_o 			=> EX_P2_w,
		P3_o 			=> EX_P3_w,
		EX_IsMul_o 		=> EX_IsMul_w
	);

	-------------------------------------------------------------------------
	-- EX/MEM PIPELINE REGISTER
	-------------------------------------------------------------------------
	inst_EX_MEM_REG: entity work.EX_MEM_REG
	GENERIC MAP (
		PC_WIDTH 		=> PC_WIDTH,
		DATA_BUS_WIDTH 	=> 32
	)
	PORT MAP (
		clk_i 				=> mclk_w,
		rst_i 				=> rst_internal,
		Flush_i 			=> EX_MEM_Flush_w,
		
		EX_PC_i 			=> EX_pc_w,
		EX_PC_PLUS4_i 		=> EX_pc_plus4_w,
		EX_Instruction_i 	=> EX_instruction_w,
		EX_ALURes_i 		=> EX_ALURes_w,
		EX_BrTaken_i 		=> EX_BrTaken_w,
		EX_BranchTarget_i 	=> EX_BranchTarget_w,
		EX_rd_i 			=> EX_rd_w,
		EX_WriteData_i 		=> EX_store_data_fwd_w,
		EX_P0_i 			=> EX_P0_w,
		EX_P1_i 			=> EX_P1_w,
		EX_P2_i 			=> EX_P2_w,
		EX_P3_i 			=> EX_P3_w,
		EX_IsMul_i 			=> EX_IsMul_w,
		
		RegDst_ctrl_i		=> EX_RegDst_ctrl_w,
		MemtoReg_ctrl_i 	=> EX_MemtoReg_ctrl_w,
		RegWrite_ctrl_i 	=> EX_RegWrite_ctrl_w,
		MemRead_ctrl_i 		=> EX_MemRead_ctrl_w,
		MemWrite_ctrl_i 	=> EX_MemWrite_ctrl_w,
		Branch_ctrl_i 		=> EX_Branch_ctrl_w,
		Jal_ctrl_i 			=> EX_Jal_ctrl_w,
		Jalr_ctrl_i			=> EX_Jalr_ctrl_w,
		
		MEM_PC_o 			=> MEM_pc_w,
		MEM_PC_PLUS4_o 		=> MEM_pc_plus4_w,
		MEM_Instruction_o 	=> MEM_instruction_w,
		MEM_ALURes_o 		=> MEM_ALURes_w,
		MEM_BrTaken_o 		=> MEM_BrTaken_w,
		MEM_BranchTarget_o 	=> MEM_BranchTarget_w,
		MEM_rd_o 			=> MEM_rd_w,
		MEM_WriteData_o 	=> MEM_WriteData_w,
		MEM_P0_o 			=> MEM_P0_w,
		MEM_P1_o 			=> MEM_P1_w,
		MEM_P2_o 			=> MEM_P2_w,
		MEM_P3_o 			=> MEM_P3_w,
		MEM_IsMul_o 		=> MEM_IsMul_w,
		
		MEM_RegDst_ctrl_o	=> MEM_RegDst_ctrl_w,
		MEM_MemtoReg_ctrl_o => MEM_MemtoReg_ctrl_w,
		MEM_RegWrite_ctrl_o => MEM_RegWrite_ctrl_w,
		MEM_MemRead_ctrl_o 	=> MEM_MemRead_ctrl_w,
		MEM_MemWrite_ctrl_o => MEM_MemWrite_ctrl_w,
		MEM_Branch_ctrl_o 	=> MEM_Branch_ctrl_w,
		MEM_Jal_ctrl_o 		=> MEM_Jal_ctrl_w,
		MEM_Jalr_ctrl_o		=> MEM_Jalr_ctrl_w
	);

	-------------------------------------------------------------------------
	-- REDIRECT LOGIC (STAGE 4: MEM)
	-------------------------------------------------------------------------
	-- Redirect logic is handled entirely within MEM_STAGE_pipeline
	-- Data memory monitoring
	dtcm_addr_o <= MEM_dtcm_addr_w;
	dtcm_data_wr_o <= MEM_WriteData_w;
	MemWrite_ctrl_o <= MEM_MemWrite_ctrl_w;

	-------------------------------------------------------------------------
	-- STAGE 4: MEMORY
	-------------------------------------------------------------------------
	inst_MEM_STAGE: entity work.MEM_STAGE_pipeline
	GENERIC MAP (
		WORD_GRANULARITY	=> G_WORD_GRANULARITY,
		DATA_BUS_WIDTH 		=> 32,
		DTCM_ADDR_WIDTH 	=> DTCM_ADDR_WIDTH,
		WORDS_NUM 			=> DATA_WORDS_NUM,
		PC_WIDTH 			=> PC_WIDTH,
		MA_WIDTH 			=> MA_WIDTH,
		DTCM_INIT_FILE 		=> DTCM_INIT_FILE
	)
	PORT MAP (
		clk_i 				=> mclk_w,
		rst_i 				=> rst_internal,
		MEM_ALURes_i 		=> MEM_ALURes_w,
		MEM_WriteData_i 	=> MEM_WriteData_w,
		MEM_MemRead_i 		=> MEM_MemRead_ctrl_w,
		MEM_MemWrite_i 		=> MEM_MemWrite_ctrl_w,
		P0_i 				=> MEM_P0_w,
		P1_i 				=> MEM_P1_w,
		P2_i 				=> MEM_P2_w,
		P3_i 				=> MEM_P3_w,
		MEM_IsMul_i 		=> MEM_IsMul_w,
		MEM_BrTaken_i 		=> MEM_BrTaken_w,
		MEM_BranchTarget_i 	=> MEM_BranchTarget_w,
		MEM_Branch_i 		=> MEM_Branch_ctrl_w,
		MEM_Jal_i 			=> MEM_Jal_ctrl_w,
		MEM_Jalr_i 			=> MEM_Jalr_ctrl_w,
		MEM_MemData_o 		=> MEM_MemData_w,
		MEM_ExecResult_o 	=> MEM_ExecResult_w,
		dtcm_addr_o 		=> MEM_dtcm_addr_w,
		redirect_valid_o 	=> redirect_valid_w,
		redirect_target_o 	=> redirect_target_w
	);

	-------------------------------------------------------------------------
	-- MEM/WB PIPELINE REGISTER
	-------------------------------------------------------------------------
	inst_MEM_WB_REG: entity work.MEM_WB_REG
	GENERIC MAP (
		PC_WIDTH 		=> PC_WIDTH,
		DATA_BUS_WIDTH 	=> 32
	)
	PORT MAP (
		clk_i 				=> mclk_w,
		rst_i 				=> rst_internal,
		MEM_PC_i 			=> MEM_pc_w,
		MEM_PC_PLUS4_i 		=> MEM_pc_plus4_w,
		MEM_Instruction_i 	=> MEM_instruction_w,
		MEM_ExecResult_i 	=> MEM_ExecResult_w,
		MEM_MemData_i 		=> MEM_MemData_w,
		MEM_rd_i 			=> MEM_rd_w,
		RegDst_ctrl_i		=> MEM_RegDst_ctrl_w,
		MemtoReg_ctrl_i 	=> MEM_MemtoReg_ctrl_w,
		RegWrite_ctrl_i 	=> MEM_RegWrite_ctrl_w,
		
		WB_PC_o 			=> WB_pc_w,
		WB_PC_PLUS4_o 		=> WB_pc_plus4_w,
		WB_Instruction_o 	=> WB_instruction_w,
		WB_ExecResult_o 	=> WB_ExecResult_w,
		WB_MemData_o 		=> WB_MemData_w,
		WB_rd_o 			=> WB_rd_w,
		WB_RegDst_ctrl_o	=> WB_RegDst_ctrl_w,
		WB_MemtoReg_ctrl_o 	=> WB_MemtoReg_ctrl_w,
		WB_RegWrite_ctrl_o 	=> WB_RegWrite_ctrl_w
	);

	-------------------------------------------------------------------------
	-- STAGE 5: WRITE-BACK
	-------------------------------------------------------------------------
	WB_write_data_w <= ( (31 DOWNTO PC_WIDTH => '0') & WB_pc_plus4_w )
					   WHEN WB_RegDst_ctrl_w = '1' ELSE
					   WB_ExecResult_w
					   WHEN WB_MemtoReg_ctrl_w = '0' ELSE
					   WB_MemData_w;

	-------------------------------------------------------------------------
	-- TOP LEVEL DEBUG PORTS
	-------------------------------------------------------------------------
	IFpc_o 			<= IF_pc_w;
	IFinstruction_o <= IF_instruction_w;
	IDpc_o 			<= ID_pc_w;
	IDinstruction_o <= ID_instruction_w;
	EXpc_o 			<= EX_pc_w;
	EXinstruction_o <= EX_instruction_w;
	MEMpc_o 		<= MEM_pc_w;
	MEMinstruction_o<= MEM_instruction_w;
	WBpc_o 			<= WB_pc_w;
	WBinstruction_o <= WB_instruction_w;
	
	-------------------------------------------------------------------------
	-- COUNTERS & DEBUG
	-------------------------------------------------------------------------
	PROCESS(mclk_w)
	BEGIN
		IF rising_edge(mclk_w) THEN
			IF rst_internal = '1' THEN
				CLKCNT_q <= (others => '0');
				FHCNT_q  <= (others => '0');
				STCNT_q  <= (others => '0');
			ELSE
				CLKCNT_q <= CLKCNT_q + 1;
				IF redirect_valid_w = '1' THEN
					FHCNT_q <= FHCNT_q + 1;
				END IF;
				IF STCNT_Enable_w = '1' THEN
					STCNT_q <= STCNT_q + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	CLKCNT_o 		<= CLKCNT_q;
	STRIGGER_o 		<= '1' WHEN IF_pc_w(9 DOWNTO 2) = BPADDR_i ELSE '0';
	FHCNT_o 		<= FHCNT_q;
	STCNT_o 		<= STCNT_q;

END behavior;
