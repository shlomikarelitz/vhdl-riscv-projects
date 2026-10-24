LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY EX_MEM_REG IS
	GENERIC (
		PC_WIDTH 		: integer := 13;
		DATA_BUS_WIDTH 	: integer := 32
	);
	PORT (
		clk_i 				: IN STD_LOGIC;
		rst_i 				: IN STD_LOGIC;
		
		-- Control
		Flush_i 			: IN STD_LOGIC;
		
		-- Inputs from EX
		EX_PC_i 			: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EX_PC_PLUS4_i 		: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EX_Instruction_i 	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_ALURes_i 		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_BrTaken_i 		: IN STD_LOGIC;
		EX_BranchTarget_i 	: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EX_rd_i 			: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		EX_WriteData_i 		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		-- Multiplier Signals
		EX_P0_i 			: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_P1_i 			: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_P2_i 			: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_P3_i 			: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_IsMul_i 			: IN STD_LOGIC;
		
		-- Control signals from ID_EX
		RegDst_ctrl_i		: IN STD_LOGIC;
		MemtoReg_ctrl_i 	: IN STD_LOGIC;
		RegWrite_ctrl_i 	: IN STD_LOGIC;
		MemRead_ctrl_i 		: IN STD_LOGIC;
		MemWrite_ctrl_i 	: IN STD_LOGIC;
		Branch_ctrl_i 		: IN STD_LOGIC;
		Jal_ctrl_i 			: IN STD_LOGIC;
		Jalr_ctrl_i			: IN STD_LOGIC;
		
		-- Outputs to MEM
		MEM_PC_o 			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEM_PC_PLUS4_o 		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEM_Instruction_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_ALURes_o 		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_BrTaken_o 		: OUT STD_LOGIC;
		MEM_BranchTarget_o 	: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEM_rd_o 			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		MEM_WriteData_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		-- Multiplier Signals
		MEM_P0_o 			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		MEM_P1_o 			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		MEM_P2_o 			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		MEM_P3_o 			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		MEM_IsMul_o 		: OUT STD_LOGIC;
		
		-- Control signals to MEM/WB
		MEM_RegDst_ctrl_o	: OUT STD_LOGIC;
		MEM_MemtoReg_ctrl_o : OUT STD_LOGIC;
		MEM_RegWrite_ctrl_o : OUT STD_LOGIC;
		MEM_MemRead_ctrl_o 	: OUT STD_LOGIC;
		MEM_MemWrite_ctrl_o : OUT STD_LOGIC;
		MEM_Branch_ctrl_o 	: OUT STD_LOGIC;
		MEM_Jal_ctrl_o 		: OUT STD_LOGIC;
		MEM_Jalr_ctrl_o		: OUT STD_LOGIC
	);
END EX_MEM_REG;

ARCHITECTURE behavior OF EX_MEM_REG IS
BEGIN
	PROCESS (clk_i)
	BEGIN
		IF rising_edge(clk_i) THEN
			IF rst_i = '1' THEN
				MEM_PC_o 			<= (OTHERS => '0');
				MEM_PC_PLUS4_o 		<= (OTHERS => '0');
				MEM_Instruction_o 	<= x"00000013"; -- NOP
				MEM_ALURes_o 		<= (OTHERS => '0');
				MEM_BrTaken_o 		<= '0';
				MEM_BranchTarget_o 	<= (OTHERS => '0');
				MEM_rd_o 			<= (OTHERS => '0');
				MEM_WriteData_o 	<= (OTHERS => '0');
				MEM_P0_o 			<= (OTHERS => '0');
				MEM_P1_o 			<= (OTHERS => '0');
				MEM_P2_o 			<= (OTHERS => '0');
				MEM_P3_o 			<= (OTHERS => '0');
				MEM_IsMul_o 		<= '0';
				
				MEM_RegDst_ctrl_o	<= '0';
				MEM_MemtoReg_ctrl_o <= '0';
				MEM_RegWrite_ctrl_o <= '0';
				MEM_MemRead_ctrl_o 	<= '0';
				MEM_MemWrite_ctrl_o <= '0';
				MEM_Branch_ctrl_o 	<= '0';
				MEM_Jal_ctrl_o 		<= '0';
				MEM_Jalr_ctrl_o		<= '0';
			ELSE
				IF Flush_i = '1' THEN
					-- Flush overrides normal pass-through
					MEM_PC_o 			<= EX_PC_i;
					MEM_PC_PLUS4_o 		<= EX_PC_PLUS4_i;
					MEM_Instruction_o 	<= x"00000013"; -- NOP
					MEM_ALURes_o 		<= EX_ALURes_i;
					MEM_BrTaken_o 		<= '0';
					MEM_BranchTarget_o 	<= EX_BranchTarget_i;
					MEM_rd_o 			<= EX_rd_i;
					MEM_WriteData_o 	<= EX_WriteData_i;
					MEM_P0_o 			<= EX_P0_i;
					MEM_P1_o 			<= EX_P1_i;
					MEM_P2_o 			<= EX_P2_i;
					MEM_P3_o 			<= EX_P3_i;
					MEM_IsMul_o 		<= '0';
					
					-- Zeroing control bundle for bubble/flush
					MEM_RegDst_ctrl_o	<= '0';
					MEM_MemtoReg_ctrl_o <= '0';
					MEM_RegWrite_ctrl_o <= '0';
					MEM_MemRead_ctrl_o 	<= '0';
					MEM_MemWrite_ctrl_o <= '0';
					MEM_Branch_ctrl_o 	<= '0';
					MEM_Jal_ctrl_o 		<= '0';
					MEM_Jalr_ctrl_o		<= '0';
				ELSE
					MEM_PC_o 			<= EX_PC_i;
					MEM_PC_PLUS4_o 		<= EX_PC_PLUS4_i;
					MEM_Instruction_o 	<= EX_Instruction_i;
					MEM_ALURes_o 		<= EX_ALURes_i;
					MEM_BrTaken_o 		<= EX_BrTaken_i;
					MEM_BranchTarget_o 	<= EX_BranchTarget_i;
					MEM_rd_o 			<= EX_rd_i;
					MEM_WriteData_o 	<= EX_WriteData_i;
					MEM_P0_o 			<= EX_P0_i;
					MEM_P1_o 			<= EX_P1_i;
					MEM_P2_o 			<= EX_P2_i;
					MEM_P3_o 			<= EX_P3_i;
					MEM_IsMul_o 		<= EX_IsMul_i;
					
					MEM_RegDst_ctrl_o	<= RegDst_ctrl_i;
					MEM_MemtoReg_ctrl_o <= MemtoReg_ctrl_i;
					MEM_RegWrite_ctrl_o <= RegWrite_ctrl_i;
					MEM_MemRead_ctrl_o 	<= MemRead_ctrl_i;
					MEM_MemWrite_ctrl_o <= MemWrite_ctrl_i;
					MEM_Branch_ctrl_o 	<= Branch_ctrl_i;
					MEM_Jal_ctrl_o 		<= Jal_ctrl_i;
					MEM_Jalr_ctrl_o		<= Jalr_ctrl_i;
				END IF;
			END IF;
		END IF;
	END PROCESS;

END behavior;
