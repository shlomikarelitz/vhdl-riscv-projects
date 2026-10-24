LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

LIBRARY work;
USE work.cond_compilation_package.all;
USE work.const_package.all;

ENTITY STALL_UNIT IS
	PORT(
		ID_instruction_i 	: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		EX_rd_i 			: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		EX_MemRead_i 		: IN STD_LOGIC;
		
		PC_WriteEnable_o 	: OUT STD_LOGIC;
		IF_ID_WriteEnable_o : OUT STD_LOGIC;
		ID_EX_Bubble_o 		: OUT STD_LOGIC;
		STCNT_Enable_o 		: OUT STD_LOGIC
	);
END STALL_UNIT;

ARCHITECTURE behavior OF STALL_UNIT IS
	SIGNAL opcode 		: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL ID_rs1 		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL ID_rs2 		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	
	SIGNAL uses_rs1 	: STD_LOGIC;
	SIGNAL uses_rs2 	: STD_LOGIC;
	
	SIGNAL hazard 		: STD_LOGIC;
	
	-- Local Constants for opcodes not explicitly named in const_package
	CONSTANT LOAD_OPC 	: STD_LOGIC_VECTOR(6 DOWNTO 0) := "0000011";
	CONSTANT JALR_OPC 	: STD_LOGIC_VECTOR(6 DOWNTO 0) := "1100111";
BEGIN
	opcode <= ID_instruction_i(6 DOWNTO 0);
	ID_rs1 <= ID_instruction_i(19 DOWNTO 15);
	ID_rs2 <= ID_instruction_i(24 DOWNTO 20);

	-- Determine if the current instruction in ID uses rs1
	uses_rs1 <= '1' WHEN (opcode = RTYPE_OPC OR 
						  opcode = ITYPE_OPC OR
						  opcode = STYPE_OPC OR
						  opcode = SBTYPE_OPC OR
						  opcode = LOAD_OPC OR
						  opcode = JALR_OPC)
					ELSE '0';

	-- Determine if the current instruction in ID uses rs2
	uses_rs2 <= '1' WHEN (opcode = RTYPE_OPC OR 
						  opcode = STYPE_OPC OR
						  opcode = SBTYPE_OPC)
					ELSE '0';

	-- Check for Load-Use Hazard
	hazard <= '1' WHEN (EX_MemRead_i = '1' AND EX_rd_i /= "00000" AND
					   ((uses_rs1 = '1' AND ID_rs1 = EX_rd_i) OR
					    (uses_rs2 = '1' AND ID_rs2 = EX_rd_i)))
				  ELSE '0';

	-- Output assignments based on hazard detection
	PC_WriteEnable_o    <= '0' WHEN hazard = '1' ELSE '1';
	IF_ID_WriteEnable_o <= '0' WHEN hazard = '1' ELSE '1';
	ID_EX_Bubble_o      <= '1' WHEN hazard = '1' ELSE '0';
	STCNT_Enable_o      <= '1' WHEN hazard = '1' ELSE '0';

END behavior;
