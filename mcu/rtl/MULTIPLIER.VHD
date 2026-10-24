--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Multiplier16 module: 16x16 -> 32 bit multiplier, built from four 8x8
-- partial-product multipliers (mapped onto the FPGA's embedded multipliers)
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;


ENTITY Multiplier16 IS
	generic(
		DATA_BUS_WIDTH 	: integer := 32
	);
	PORT(
		--Inputs
		Ain_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		Bin_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		--Outputs
		Res_o 	: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END Multiplier16;


ARCHITECTURE struct OF Multiplier16 IS
	SIGNAL a_low_w		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL a_high_w		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL b_low_w		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL b_high_w		: STD_LOGIC_VECTOR(7 DOWNTO 0);

	SIGNAL p0_w				: STD_LOGIC_VECTOR(15 DOWNTO 0);	-- P0 = A_low  x B_low
	SIGNAL p1_w				: STD_LOGIC_VECTOR(15 DOWNTO 0);	-- P1 = A_low  x B_high
	SIGNAL p2_w				: STD_LOGIC_VECTOR(15 DOWNTO 0);	-- P2 = A_high x B_low
	SIGNAL p3_w				: STD_LOGIC_VECTOR(15 DOWNTO 0);	-- P3 = A_high x B_high

	SIGNAL m_w				: STD_LOGIC_VECTOR(16 DOWNTO 0);	-- M = P1 + P2

BEGIN
	-- Operands are the lower half-word (16-bit) of rs1/rs2, split into bytes
	a_low_w		<= Ain_i(7 DOWNTO 0);
	a_high_w	<= Ain_i(15 DOWNTO 8);
	b_low_w		<= Bin_i(7 DOWNTO 0);
	b_high_w	<= Bin_i(15 DOWNTO 8);

	--========================================================================
	-- Stage 1: four 8x8 -> 16-bit partial products
	--========================================================================
	p0_w <= a_low_w  * b_low_w;
	p1_w <= a_low_w  * b_high_w;
	p2_w <= a_high_w * b_low_w;
	p3_w <= a_high_w * b_high_w;

	--========================================================================
	-- Stage 2: M = P1 + P2 ; RESULT = P0 + (M << 8) + (P3 << 16)
	--========================================================================
	m_w <= ('0' & p1_w) + ('0' & p2_w);

	Res_o <= (X"0000" & p0_w)
				 + ("0000000" & m_w & X"00")
				 + (p3_w & X"0000");

END struct;
