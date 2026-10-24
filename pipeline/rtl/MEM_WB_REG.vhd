LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY MEM_WB_REG IS
	GENERIC (
		PC_WIDTH 		: integer := 13;
		DATA_BUS_WIDTH 	: integer := 32
	);
	PORT (
		clk_i 				: IN STD_LOGIC;
		rst_i 				: IN STD_LOGIC;
		
		-- Inputs from MEM
		MEM_PC_i 			: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEM_PC_PLUS4_i 		: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEM_Instruction_i 	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_ExecResult_i 	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_MemData_i 		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_rd_i 			: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		
		-- Control signals from EX_MEM
		RegDst_ctrl_i		: IN STD_LOGIC;
		MemtoReg_ctrl_i 	: IN STD_LOGIC;
		RegWrite_ctrl_i 	: IN STD_LOGIC;
		
		-- Outputs to WB
		WB_PC_o 			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		WB_PC_PLUS4_o 		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		WB_Instruction_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		WB_ExecResult_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		WB_MemData_o 		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		WB_rd_o 			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		
		-- Control signals to WB
		WB_RegDst_ctrl_o	: OUT STD_LOGIC;
		WB_MemtoReg_ctrl_o 	: OUT STD_LOGIC;
		WB_RegWrite_ctrl_o 	: OUT STD_LOGIC
	);
END MEM_WB_REG;

ARCHITECTURE behavior OF MEM_WB_REG IS
BEGIN
	PROCESS (clk_i)
	BEGIN
		IF rising_edge(clk_i) THEN
			IF rst_i = '1' THEN
				WB_PC_o 			<= (OTHERS => '0');
				WB_PC_PLUS4_o 		<= (OTHERS => '0');
				WB_Instruction_o 	<= x"00000013"; -- NOP
				WB_ExecResult_o 	<= (OTHERS => '0');
				WB_MemData_o 		<= (OTHERS => '0');
				WB_rd_o 			<= (OTHERS => '0');
				
				WB_RegDst_ctrl_o	<= '0';
				WB_MemtoReg_ctrl_o 	<= '0';
				WB_RegWrite_ctrl_o 	<= '0';
			ELSE
				-- No flush for MEM_WB. Always pass through!
				WB_PC_o 			<= MEM_PC_i;
				WB_PC_PLUS4_o 		<= MEM_PC_PLUS4_i;
				WB_Instruction_o 	<= MEM_Instruction_i;
				WB_ExecResult_o 	<= MEM_ExecResult_i;
				WB_MemData_o 		<= MEM_MemData_i;
				WB_rd_o 			<= MEM_rd_i;
				
				WB_RegDst_ctrl_o	<= RegDst_ctrl_i;
				WB_MemtoReg_ctrl_o 	<= MemtoReg_ctrl_i;
				WB_RegWrite_ctrl_o 	<= RegWrite_ctrl_i;
			END IF;
		END IF;
	END PROCESS;

END behavior;
