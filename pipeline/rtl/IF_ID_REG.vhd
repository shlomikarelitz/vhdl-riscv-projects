LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY IF_ID_REG IS
	GENERIC (
		PC_WIDTH 		: integer := 13;
		DATA_BUS_WIDTH 	: integer := 32
	);
	PORT (
		clk_i 				: IN STD_LOGIC;
		rst_i 				: IN STD_LOGIC;
		
		-- Control
		IF_ID_WriteEnable_i : IN STD_LOGIC;
		Flush_i 			: IN STD_LOGIC;
		
		-- Inputs from IF
		IF_PC_i 			: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IF_PC_PLUS4_i 		: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IF_Instruction_i 	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		-- Outputs to ID
		ID_PC_o 			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		ID_PC_PLUS4_o 		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		ID_Instruction_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END IF_ID_REG;

ARCHITECTURE behavior OF IF_ID_REG IS
	SIGNAL pc_q 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_q 	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL inst_q 		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
BEGIN
	PROCESS (clk_i)
	BEGIN
		IF rising_edge(clk_i) THEN
			IF rst_i = '1' THEN
				pc_q 		<= (OTHERS => '0');
				pc_plus4_q 	<= (OTHERS => '0');
				inst_q 		<= x"00000013"; -- NOP (addi x0, x0, 0)
			ELSE
				-- Flush has priority over Stall
				IF Flush_i = '1' THEN
					pc_q 		<= (OTHERS => '0');
					pc_plus4_q 	<= (OTHERS => '0');
					inst_q 		<= x"00000013"; -- NOP
				ELSIF IF_ID_WriteEnable_i = '1' THEN
					pc_q 		<= IF_PC_i;
					pc_plus4_q 	<= IF_PC_PLUS4_i;
					inst_q 		<= IF_Instruction_i;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	ID_PC_o 		<= pc_q;
	ID_PC_PLUS4_o 	<= pc_plus4_q;
	ID_Instruction_o <= inst_q;

END behavior;
