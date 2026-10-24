LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY ID_EX_REG IS
	GENERIC (
		PC_WIDTH 		: integer := 13;
		DATA_BUS_WIDTH 	: integer := 32
	);
	PORT (
		clk_i 				: IN STD_LOGIC;
		rst_i 				: IN STD_LOGIC;
		
		-- Control
		Bubble_i 			: IN STD_LOGIC;
		Flush_i 			: IN STD_LOGIC;
		
		-- Inputs from ID
		ID_PC_i 			: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		ID_PC_PLUS4_i 		: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		ID_Instruction_i 	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data1_i 		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_i 		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		SignExt_i 			: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		rs1_i 				: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		rs2_i 				: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		rd_i 				: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		
		-- Control signals from CONTROL
		RegDst_ctrl_i		: IN STD_LOGIC;
		ALUSrc_ctrl_i 		: IN STD_LOGIC;
		MemtoReg_ctrl_i 	: IN STD_LOGIC;
		RegWrite_ctrl_i 	: IN STD_LOGIC;
		MemRead_ctrl_i 		: IN STD_LOGIC;
		MemWrite_ctrl_i 	: IN STD_LOGIC;
		Branch_ctrl_i 		: IN STD_LOGIC;
		Jal_ctrl_i 			: IN STD_LOGIC;
		Jalr_ctrl_i			: IN STD_LOGIC;
		UpperIm_ctrl_i 		: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_i 		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		
		-- Outputs to EX
		EX_PC_o 			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EX_PC_PLUS4_o 		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EX_Instruction_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_read_data1_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_read_data2_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_SignExt_o 		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_rs1_o 			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		EX_rs2_o 			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		EX_rd_o 			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		
		-- Control signals to EX/MEM/WB
		EX_RegDst_ctrl_o	: OUT STD_LOGIC;
		EX_ALUSrc_ctrl_o 	: OUT STD_LOGIC;
		EX_MemtoReg_ctrl_o 	: OUT STD_LOGIC;
		EX_RegWrite_ctrl_o 	: OUT STD_LOGIC;
		EX_MemRead_ctrl_o 	: OUT STD_LOGIC;
		EX_MemWrite_ctrl_o 	: OUT STD_LOGIC;
		EX_Branch_ctrl_o 	: OUT STD_LOGIC;
		EX_Jal_ctrl_o 		: OUT STD_LOGIC;
		EX_Jalr_ctrl_o		: OUT STD_LOGIC;
		EX_UpperIm_ctrl_o 	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		EX_ALUOp_ctrl_o 	: OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
END ID_EX_REG;

ARCHITECTURE behavior OF ID_EX_REG IS
BEGIN
	PROCESS (clk_i)
	BEGIN
		IF rising_edge(clk_i) THEN
			IF rst_i = '1' THEN
				EX_PC_o 			<= (OTHERS => '0');
				EX_PC_PLUS4_o 		<= (OTHERS => '0');
				EX_Instruction_o 	<= x"00000013"; -- NOP
				EX_read_data1_o 	<= (OTHERS => '0');
				EX_read_data2_o 	<= (OTHERS => '0');
				EX_SignExt_o 		<= (OTHERS => '0');
				EX_rs1_o 			<= (OTHERS => '0');
				EX_rs2_o 			<= (OTHERS => '0');
				EX_rd_o 			<= (OTHERS => '0');
				
				EX_RegDst_ctrl_o	<= '0';
				EX_ALUSrc_ctrl_o 	<= '0';
				EX_MemtoReg_ctrl_o 	<= '0';
				EX_RegWrite_ctrl_o 	<= '0';
				EX_MemRead_ctrl_o 	<= '0';
				EX_MemWrite_ctrl_o 	<= '0';
				EX_Branch_ctrl_o 	<= '0';
				EX_Jal_ctrl_o 		<= '0';
				EX_Jalr_ctrl_o		<= '0';
				EX_UpperIm_ctrl_o 	<= "00";
				EX_ALUOp_ctrl_o 	<= "00000";
			ELSE
				IF Flush_i = '1' OR Bubble_i = '1' THEN
					EX_PC_o 			<= ID_PC_i; 			-- Keeping PC might be useful for debug
					EX_PC_PLUS4_o 		<= ID_PC_PLUS4_i;
					EX_Instruction_o 	<= x"00000013"; 		-- NOP
					EX_read_data1_o 	<= read_data1_i;
					EX_read_data2_o 	<= read_data2_i;
					EX_SignExt_o 		<= SignExt_i;
					EX_rs1_o 			<= rs1_i;
					EX_rs2_o 			<= rs2_i;
					EX_rd_o 			<= rd_i;
					
					-- Zeroing control bundle for bubble/flush
					EX_RegDst_ctrl_o	<= '0';
					EX_ALUSrc_ctrl_o 	<= '0';
					EX_MemtoReg_ctrl_o 	<= '0';
					EX_RegWrite_ctrl_o 	<= '0';
					EX_MemRead_ctrl_o 	<= '0';
					EX_MemWrite_ctrl_o 	<= '0';
					EX_Branch_ctrl_o 	<= '0';
					EX_Jal_ctrl_o 		<= '0';
					EX_Jalr_ctrl_o		<= '0';
					EX_UpperIm_ctrl_o 	<= "00";
					EX_ALUOp_ctrl_o 	<= "00000";
				ELSE
					EX_PC_o 			<= ID_PC_i;
					EX_PC_PLUS4_o 		<= ID_PC_PLUS4_i;
					EX_Instruction_o 	<= ID_Instruction_i;
					EX_read_data1_o 	<= read_data1_i;
					EX_read_data2_o 	<= read_data2_i;
					EX_SignExt_o 		<= SignExt_i;
					EX_rs1_o 			<= rs1_i;
					EX_rs2_o 			<= rs2_i;
					EX_rd_o 			<= rd_i;
					
					EX_RegDst_ctrl_o	<= RegDst_ctrl_i;
					EX_ALUSrc_ctrl_o 	<= ALUSrc_ctrl_i;
					EX_MemtoReg_ctrl_o 	<= MemtoReg_ctrl_i;
					EX_RegWrite_ctrl_o 	<= RegWrite_ctrl_i;
					EX_MemRead_ctrl_o 	<= MemRead_ctrl_i;
					EX_MemWrite_ctrl_o 	<= MemWrite_ctrl_i;
					EX_Branch_ctrl_o 	<= Branch_ctrl_i;
					EX_Jal_ctrl_o 		<= Jal_ctrl_i;
					EX_Jalr_ctrl_o		<= Jalr_ctrl_i;
					EX_UpperIm_ctrl_o 	<= UpperIm_ctrl_i;
					EX_ALUOp_ctrl_o 	<= ALUOp_ctrl_i;
				END IF;
			END IF;
		END IF;
	END PROCESS;

END behavior;
