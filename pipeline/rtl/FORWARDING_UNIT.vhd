LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY FORWARDING_UNIT IS
	PORT(
		EX_rs1_i 		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		EX_rs2_i 		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		
		MEM_rd_i 		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		MEM_RegWrite_i 	: IN STD_LOGIC;
		MEM_MemtoReg_i 	: IN STD_LOGIC;
		
		WB_rd_i 		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		WB_RegWrite_i 	: IN STD_LOGIC;
		
		ForwardA_o 		: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		ForwardB_o 		: OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
	);
END FORWARDING_UNIT;

ARCHITECTURE behavior OF FORWARDING_UNIT IS
BEGIN

	PROCESS(EX_rs1_i, EX_rs2_i, MEM_rd_i, MEM_RegWrite_i, MEM_MemtoReg_i, WB_rd_i, WB_RegWrite_i)
	BEGIN
		-- Default values
		ForwardA_o <= "00";
		ForwardB_o <= "00";
		
		-- Forwarding for rs1 (Operand A)
		IF (MEM_RegWrite_i = '1' AND MEM_rd_i /= "00000" AND MEM_rd_i = EX_rs1_i AND MEM_MemtoReg_i = '0') THEN
			ForwardA_o <= "01"; -- Forward from MEM
		ELSIF (WB_RegWrite_i = '1' AND WB_rd_i /= "00000" AND WB_rd_i = EX_rs1_i) THEN
			ForwardA_o <= "10"; -- Forward from WB
		END IF;
		
		-- Forwarding for rs2 (Operand B / Store Data)
		IF (MEM_RegWrite_i = '1' AND MEM_rd_i /= "00000" AND MEM_rd_i = EX_rs2_i AND MEM_MemtoReg_i = '0') THEN
			ForwardB_o <= "01"; -- Forward from MEM
		ELSIF (WB_RegWrite_i = '1' AND WB_rd_i /= "00000" AND WB_rd_i = EX_rs2_i) THEN
			ForwardB_o <= "10"; -- Forward from WB
		END IF;
		
	END PROCESS;

END behavior;
