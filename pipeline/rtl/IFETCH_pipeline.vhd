--============================================================================
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- IFETCH module for Pipelined RISC-V Core
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;


ENTITY Ifetch_pipeline IS
	generic(
		WORD_GRANULARITY 	: boolean	:= False;
		DATA_BUS_WIDTH 		: integer	:= 32;
		PC_WIDTH 			: integer	:= 13;
		ITCM_ADDR_WIDTH 	: integer	:= 11;
		WORDS_NUM 			: integer	:= 2048;
		ITCM_INIT_FILE 		: string 	:= "programs/rt5/ITCM.hex"
	);
	PORT(
		--Inputs
		clk_i				: IN 	STD_LOGIC;
		rst_i 				: IN 	STD_LOGIC;
		
		-- Pipeline Control
		PC_WriteEnable_i 	: IN 	STD_LOGIC;
		redirect_valid_i 	: IN 	STD_LOGIC;
		redirect_target_i 	: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		
		--Outputs
		pc_o 				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		pc_plus4_o 			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_o 		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END Ifetch_pipeline;


ARCHITECTURE behavior OF Ifetch_pipeline IS
	SIGNAL pc_q					: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_w 			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL itcm_addr_w			: STD_LOGIC_VECTOR(ITCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL next_pc_w  			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	
BEGIN
	--=======================================
	-- ITCM (ROM) connection
	--=======================================
	inst_memory: altsyncram
	GENERIC MAP (
		operation_mode			=> "ROM",
		width_a 				=> DATA_BUS_WIDTH,
		widthad_a 				=> ITCM_ADDR_WIDTH,
		numwords_a 				=> WORDS_NUM,
		lpm_hint 				=> "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = ITCM",
		lpm_type 				=> "altsyncram",
		outdata_reg_a 			=> "UNREGISTERED",
		init_file 				=> ITCM_INIT_FILE,
		intended_device_family	=> "Cyclone V"
	)
	PORT MAP (
		clock0    => clk_i,
		address_a => itcm_addr_w, 
		q_a 	  => instruction_o 
	);

-----------------------------------------------------------------------------------		
	-- Combinational PC+4 calculation based on current PC (not next_pc_w!)
	-- In pipeline, if we stall, we shouldn't advance PC. 
	pc_plus4_w <= pc_q + 4;
	
-----------------------------------------------------------------------------------
	-- Decision MUX for the next PC value
	next_pc_w	<=	(others => '0') WHEN rst_i = '1' ELSE
					redirect_target_i WHEN redirect_valid_i = '1' ELSE
					pc_q WHEN PC_WriteEnable_i = '0' ELSE
					pc_plus4_w;
					
-----------------------------------------------------------------------------------
-- pc register
-------------------------------------------------------------------------------------
PROCESS (clk_i)
	BEGIN
		IF rising_edge(clk_i) THEN
			IF rst_i = '1' THEN
				pc_q <= (OTHERS => '0'); 
			-- No need for ELSIF PC_WriteEnable_i = '1' because next_pc_w already holds pc_q when stalled
			ELSE
				pc_q <= next_pc_w;	
			END IF;
		END IF;
END PROCESS;

-----------------------------------------------------------------------------------	
	-- send address to inst. memory address register
	-- We always use next_pc_w so that altsyncram registers the address and outputs data on the next cycle (aligned with pc_q)
	G1: 
	if (WORD_GRANULARITY = True) generate 			
		itcm_addr_w <= next_pc_w(PC_WIDTH-1 DOWNTO 2);
	elsif (WORD_GRANULARITY = False) generate 	
		itcm_addr_w <= next_pc_w;
	end generate;
---------------------------------------------------------------------------------------
	pc_o 		<= pc_q;
	pc_plus4_o	<= pc_plus4_w;	
---------------------------------------------------------------------------------------
	
END behavior;
