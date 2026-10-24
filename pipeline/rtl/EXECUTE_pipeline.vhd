LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE work.const_package.all;
USE work.aux_package.all;

ENTITY  Execute_pipeline IS
	generic(
		DATA_BUS_WIDTH 	: integer := 32;
		PC_WIDTH 		: integer := 13
	);
	PORT(	
		--Inputs
		read_data1_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		sign_extend_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		UpperIm_ctrl_i	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_i	: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
		ALUSrc_ctrl_i 	: IN 	STD_LOGIC;
		pc_i			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			
		--Outputs
		brTaken_o 		: OUT	STD_LOGIC;
		alu_res_o 		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		addr_gen_o 		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		
		-- Multiplier Partial Products
		P0_o 			: OUT 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		P1_o 			: OUT 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		P2_o 			: OUT 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		P3_o 			: OUT 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_IsMul_o 		: OUT 	STD_LOGIC
	);
END Execute_pipeline;

ARCHITECTURE struct OF Execute_pipeline IS
	SIGNAL 	ain_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	bin_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	alu_res_r 		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL EX_mul_res_w : STD_LOGIC_VECTOR(31 DOWNTO 0);
	attribute keep : boolean;
	attribute keep of EX_mul_res_w : signal is true;
	SIGNAL 	sub_res_w 		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	ltu_res_w 		: STD_LOGIC;
	SIGNAL 	eq_res_w		: STD_LOGIC;
	SIGNAL	msbneq_res_w	: STD_LOGIC;

	SIGNAL	brTaken_w 		: STD_LOGIC;
	
	SIGNAL	brl_shl_s1_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shl_s2_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shl_s3_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shl_s4_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	
	SIGNAL	brl_shr_s1_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shr_s2_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shr_s3_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shr_s4_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shr_pad_r	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- Multiplier partial product inputs
	SIGNAL a_low_w			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL a_high_w			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL b_low_w			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL b_high_w			: STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN
--------------------------------------------------------------------------------------------------------
-- 16x16 -> 32 multiplier partial products calculation
--------------------------------------------------------------------------------------------------------
	-- Operands are the lower half-word (16-bit) of rs1/rs2, split into bytes
	-- IMPORTANT: VHDL '*' operator with STD_LOGIC_SIGNED treats operands as signed.
	-- However, the original MULTIPLIER.VHD used STD_LOGIC_UNSIGNED.
	-- We will use UNSIGNED casting to get the correct partial products here just like the original.
	a_low_w		<= ain_w(7 DOWNTO 0);
	a_high_w	<= ain_w(15 DOWNTO 8);
	b_low_w		<= bin_w(7 DOWNTO 0);
	b_high_w	<= bin_w(15 DOWNTO 8);

	P0_o <= unsigned(a_low_w)  * unsigned(b_low_w);
	P1_o <= unsigned(a_low_w)  * unsigned(b_high_w);
	P2_o <= unsigned(a_high_w) * unsigned(b_low_w);
	P3_o <= unsigned(a_high_w) * unsigned(b_high_w);

	-- Assign lower 32-bit result from multiplier partial products
	EX_mul_res_w <= P1_o & P0_o;

	EX_IsMul_o <= '1' WHEN ALUOp_ctrl_i = ALU_MUL ELSE '0';

--------------------------------------------------------------------------------------------------------
-- Branch Address Adder
--------------------------------------------------------------------------------------------------------					  
addr_gen_o	<= pc_i(PC_WIDTH-1 DOWNTO 0) + (sign_extend_i(PC_WIDTH-3 DOWNTO 0) & '0');

--------------------------------------------------------------------------------------------------------
--ALU
--------------------------------------------------------------------------------------------------------
WITH UpperIm_ctrl_i SELECT
	ain_w <= 	read_data1_i																					WHEN	"00",
						((DATA_BUS_WIDTH-PC_WIDTH-1) DOWNTO 0 => '0') & pc_i	WHEN	"01",
						(others => '0')	WHEN	OTHERS;
	
bin_w <= 	read_data2_i	WHEN not ALUSrc_ctrl_i ELSE	sign_extend_i(DATA_BUS_WIDTH-1 DOWNTO 0);

--Reused resuls 
sub_res_w			<= ain_w - bin_w;
ltu_res_w			<= '1' WHEN unsigned(ain_w) < unsigned(bin_w) 	ELSE '0'; -- Ensure unsigned comparison
eq_res_w			<= '1' WHEN ain_w = bin_w 					ELSE '0'; 
msbneq_res_w	<= '1' WHEN ain_w(31) /= bin_w(31) 	ELSE '0';

PROCESS (all)
BEGIN
	-- default values
	alu_res_r 		<= (others => '0');
	brTaken_w 		<= '0';
	brl_shl_s1_r	<= (others => '0');
	brl_shl_s2_r	<= (others => '0');
	brl_shl_s3_r	<= (others => '0'); 
	brl_shl_s4_r	<= (others => '0');
	brl_shr_s1_r	<= (others => '0');
	brl_shr_s2_r	<= (others => '0');
	brl_shr_s3_r	<= (others => '0'); 
	brl_shr_s4_r	<= (others => '0');
	brl_shr_pad_r	<= (others => '0');
	
 	CASE ALUOp_ctrl_i IS
		------------------------------------------------------
		-- Arithmetic
		------------------------------------------------------
		WHEN ALU_ADD 	=>
			alu_res_r	<= ain_w + bin_w;
			brTaken_w	<= '0';
		
		WHEN ALU_SUB	=>
			alu_res_r	<= sub_res_w;
			brTaken_w	<= '0';

		-- mul (Partial products calculated concurrently)
		WHEN ALU_MUL	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= '0';

		------------------------------------------------------
		-- Logic
		------------------------------------------------------
		WHEN ALU_AND 	=>
			alu_res_r	<= ain_w and bin_w;
			brTaken_w	<= '0';
		
	 	WHEN ALU_OR	=>
			alu_res_r	<= ain_w or bin_w;
			brTaken_w	<= '0';
		
		WHEN ALU_XOR 	=>
			alu_res_r	<= ain_w xor bin_w;
			brTaken_w	<= '0';
				
		------------------------------------------------------
		-- Shift Left
		------------------------------------------------------
 	 	WHEN ALU_SHIFTL	=>
			if (bin_w(0) = '1') then
				brl_shl_s1_r <= (ain_w(30 DOWNTO 0) & '0');
			else
				brl_shl_s1_r <= ain_w;
			end if;
					
			if (bin_w(1) = '1') then
				brl_shl_s2_r <= (brl_shl_s1_r(29 DOWNTO 0) & "00");
			else
				brl_shl_s2_r <= brl_shl_s1_r;
			end if;
					
			if (bin_w(2) = '1')	then
				brl_shl_s3_r <= (brl_shl_s2_r(27 DOWNTO 0) & "0000");
			else
				brl_shl_s3_r <= brl_shl_s2_r;
			end if;
					
			if (bin_w(3) = '1')	then
				brl_shl_s4_r <= (brl_shl_s3_r(23 DOWNTO 0) & "00000000");
			else
				brl_shl_s4_r <= brl_shl_s3_r;
			end if;
					
			if (bin_w(4) = '1')	then
				alu_res_r <= (brl_shl_s4_r(15 DOWNTO 0) & "0000000000000000");
			else
				alu_res_r <= brl_shl_s4_r;
			end if;
				      
			brTaken_w	<= '0';

		------------------------------------------------------
		-- Shift Right
		------------------------------------------------------		
 	 	WHEN ALU_SHIFTR | ALU_SHIFTR_ARITH 	=>
			if (ain_w(31) = '1' and (ALUOp_ctrl_i = ALU_SHIFTR_ARITH)) then
				brl_shr_pad_r <= 32x"FFFF";
			else
				brl_shr_pad_r <= 32x"0000";
			end if;
			
			if (bin_w(0) = '1') then
				brl_shr_s1_r <= (brl_shr_pad_r(31) & ain_w(31 DOWNTO 1));
			else
				brl_shr_s1_r <= ain_w;
			end if;
			
			if (bin_w(1) = '1') then
				brl_shr_s2_r <= (brl_shr_pad_r(31 DOWNTO 30) & brl_shr_s1_r(31 DOWNTO 2));
			else
				brl_shr_s2_r <= brl_shr_s1_r;
			end if;
			
			if (bin_w(2) = '1') then
				brl_shr_s3_r <= (brl_shr_pad_r(31 DOWNTO 28) & brl_shr_s2_r(31 DOWNTO 4));
			else
				brl_shr_s3_r <= brl_shr_s2_r;
			end if;
			
			if (bin_w(3) = '1') then
				brl_shr_s4_r <= (brl_shr_pad_r(31 DOWNTO 24) & brl_shr_s3_r(31 DOWNTO 8));
			else
				brl_shr_s4_r <= brl_shr_s3_r;
			end if;
			
			if (bin_w(4) = '1')	then
				alu_res_r <= (brl_shr_pad_r(31 DOWNTO 16) & brl_shr_s4_r(31 DOWNTO 16));
			else
				alu_res_r <= brl_shr_s4_r;
			end if;
				   
			brTaken_w	<= '0';		 	 				

		------------------------------------------------------
		-- Comparision
		------------------------------------------------------
		WHEN ALU_LESS_THAN_SIGNED	=>
			brTaken_w	<= '0';
			IF msbneq_res_w = '1' THEN
				IF ain_w(31) = '1' THEN
					alu_res_r	<= (0 => '1', others => '0');
				ELSE
					alu_res_r	<= (others => '0');
				END IF;
			ELSE
				IF sub_res_w(31) = '1' THEN
					alu_res_r	<= (0 => '1', others => '0');
				ELSE
					alu_res_r	<= (others => '0');
				END IF;
			END IF;
		
		WHEN ALU_LESS_THAN_UNSIGNED	=>
			brTaken_w	<= '0';
			IF ltu_res_w = '1' THEN
				alu_res_r	<= (0 => '1', others => '0');
			ELSE
				alu_res_r	<= (others => '0');
			END IF;

		------------------------------------------------------
		-- Condional Branch 
		------------------------------------------------------
		WHEN ALU_BEQ	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= eq_res_w;
		
		WHEN ALU_BNE	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= not eq_res_w;
		
		WHEN ALU_BLT	=>
			alu_res_r	<= (others => '0');
			IF msbneq_res_w = '1' THEN
				brTaken_w	<= ain_w(31);
			ELSE
				brTaken_w	<= sub_res_w(31);
			END IF;
		
		WHEN ALU_BGE	=>
			alu_res_r	<= (others => '0');
			IF msbneq_res_w = '1' THEN
				brTaken_w	<= bin_w(31);
			ELSE
				brTaken_w	<= not sub_res_w(31);
			END IF;
		
		WHEN ALU_BLTU	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= ltu_res_w;
		
		WHEN ALU_BGEU	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= not ltu_res_w;
		
 	 	WHEN OTHERS	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= '0';
			
  END CASE;
		
END PROCESS;
	
--------------------------------------------------------------------------------------------------------
alu_res_o	<= alu_res_r;
brTaken_o	<= brTaken_w;
 
END struct;
