LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.const_package.all;

ENTITY MEM_STAGE_pipeline IS
	GENERIC (
		WORD_GRANULARITY	: boolean := True;
		DATA_BUS_WIDTH 		: integer := 32;
		DTCM_ADDR_WIDTH 	: integer := 13;
		WORDS_NUM 			: integer := 512;
		PC_WIDTH 			: integer := 13;
		MA_WIDTH 			: integer := 32;
		DTCM_INIT_FILE  	: string := "programs/rt5/DTCM.hex"
	);
	PORT (
		clk_i 				: IN STD_LOGIC;
		rst_i 				: IN STD_LOGIC;
		
		-- ALU & WriteData
		MEM_ALURes_i 		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_WriteData_i 	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		-- Memory Control
		MEM_MemRead_i 		: IN STD_LOGIC;
		MEM_MemWrite_i 		: IN STD_LOGIC;
		
		-- Multiplier Signals
		P0_i 				: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		P1_i 				: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		P2_i 				: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		P3_i 				: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		MEM_IsMul_i 		: IN STD_LOGIC;
		
		-- Branch/Jump Control
		MEM_BrTaken_i 		: IN STD_LOGIC;
		MEM_BranchTarget_i 	: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEM_Branch_i 		: IN STD_LOGIC;
		MEM_Jal_i 			: IN STD_LOGIC;
		MEM_Jalr_i 			: IN STD_LOGIC;
		
		-- Outputs
		MEM_MemData_o 		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_ExecResult_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		-- Data memory monitoring
		dtcm_addr_o 		: OUT STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
		
		-- Redirect Signals
		redirect_valid_o 	: OUT STD_LOGIC;
		redirect_target_o 	: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0)
	);
END MEM_STAGE_pipeline;

ARCHITECTURE struct OF MEM_STAGE_pipeline IS
	SIGNAL dtcm_addr_w 		: STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL m_w 				: STD_LOGIC_VECTOR(16 DOWNTO 0);
	SIGNAL mul_result_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

BEGIN
	--------------------------------------------------------------------------------------------------------
	-- DTCM Address Generation (Preserving Single-Cycle Behavior)
	--------------------------------------------------------------------------------------------------------
	G1: 
	IF (WORD_GRANULARITY = True) GENERATE 
		dtcm_addr_w	<= MEM_ALURes_i(MA_WIDTH-1 DOWNTO 2); -- increment memory address by 4
	ELSIF (WORD_GRANULARITY = False) GENERATE
		dtcm_addr_w	<= MEM_ALURes_i(DTCM_ADDR_WIDTH-1 DOWNTO 0);
	END GENERATE G1;
	
	dtcm_addr_o <= dtcm_addr_w;

	--------------------------------------------------------------------------------------------------------
	-- Data Memory (DTCM)
	--------------------------------------------------------------------------------------------------------
	inst_DMEMORY: entity work.dmemory_pipeline
	GENERIC MAP (
		DATA_BUS_WIDTH		=> DATA_BUS_WIDTH, 
		DTCM_ADDR_WIDTH		=> DTCM_ADDR_WIDTH,
		WORDS_NUM			=> WORDS_NUM,
		DTCM_INIT_FILE 		=> DTCM_INIT_FILE
	)
	PORT MAP (	
		clk_i 				=> clk_i,  
		rst_i 				=> rst_i,
		dtcm_addr_i 		=> dtcm_addr_w,
		dtcm_data_wr_i 		=> MEM_WriteData_i,
		MemRead_ctrl_i 		=> MEM_MemRead_i, 
		MemWrite_ctrl_i 	=> MEM_MemWrite_i,
		dtcm_data_rd_o 		=> MEM_MemData_o 
	);

	--------------------------------------------------------------------------------------------------------
	-- Multiplier Stage 2
	--------------------------------------------------------------------------------------------------------
	m_w <= ('0' & P1_i) + ('0' & P2_i);

	mul_result_w <= (X"0000" & P0_i)
				 + ("0000000" & m_w & X"00")
				 + (P3_i & X"0000");

	--------------------------------------------------------------------------------------------------------
	-- ExecResult Selection
	--------------------------------------------------------------------------------------------------------
	MEM_ExecResult_o <= mul_result_w WHEN MEM_IsMul_i = '1' ELSE MEM_ALURes_i;

	--------------------------------------------------------------------------------------------------------
	-- Branch/Jump Redirect Logic
	--------------------------------------------------------------------------------------------------------
	redirect_valid_o  <= MEM_Jalr_i OR MEM_Jal_i OR (MEM_Branch_i AND MEM_BrTaken_i);
	redirect_target_o <= MEM_ALURes_i(PC_WIDTH-1 DOWNTO 0) WHEN MEM_Jalr_i = '1' ELSE MEM_BranchTarget_i;

END struct;
