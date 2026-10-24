LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;

ENTITY tb_pipeline IS
END tb_pipeline;

ARCHITECTURE behavior OF tb_pipeline IS
	SIGNAL clk_i 			: STD_LOGIC := '0';
	SIGNAL rst_i 			: STD_LOGIC := '0';
	SIGNAL BPADDR_i 		: STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');

	SIGNAL IFpc_o 			: STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL IDpc_o 			: STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL EXpc_o 			: STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL WBpc_o 			: STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL WBinstruction_o  : STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	SIGNAL dtcm_addr_o		: STD_LOGIC_VECTOR(10 DOWNTO 0);
	SIGNAL dtcm_data_wr_o	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL MemWrite_ctrl_o	: STD_LOGIC;
	
	SIGNAL STCNT_o 			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL FHCNT_o 			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL CLKCNT_o 		: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL STRIGGER_o 		: STD_LOGIC;
	
	SIGNAL sim_done : BOOLEAN := false;
BEGIN
	DUT: entity work.RV32IM_CORE_pipeline
	PORT MAP (
		clk_i 			=> clk_i,
		rst_i 			=> rst_i,
		BPADDR_i 		=> BPADDR_i,
		CLKCNT_o 		=> CLKCNT_o,
		IFpc_o 			=> IFpc_o,
		IFinstruction_o => open,
		IDpc_o 			=> IDpc_o,
		IDinstruction_o => open,
		EXpc_o 			=> EXpc_o,
		EXinstruction_o => open,
		MEMpc_o 		=> open,
		MEMinstruction_o=> open,
		WBpc_o 			=> WBpc_o,
		WBinstruction_o => WBinstruction_o,
		dtcm_addr_o		=> dtcm_addr_o,
		dtcm_data_wr_o	=> dtcm_data_wr_o,
		MemWrite_ctrl_o	=> MemWrite_ctrl_o,
		STRIGGER_o 		=> STRIGGER_o,
		FHCNT_o 		=> FHCNT_o,
		STCNT_o 		=> STCNT_o
	);

	clk_i <= not clk_i after 10 ns when not sim_done else '0';

	gen_rst: PROCESS
	BEGIN
		rst_i <= '1';
		wait for 25 ns;
		rst_i <= '0';
		wait;
	END PROCESS;

	stimulus: PROCESS
		VARIABLE cycles : INTEGER := 0;
		VARIABLE L      : std.textio.LINE;
	BEGIN
		-- Wait for reset to deassert
		wait until rst_i = '0';
		wait until rising_edge(clk_i);

		std.textio.write(L, string'("================================================"));
		std.textio.writeline(std.textio.OUTPUT, L);
		std.textio.write(L, string'(" RV32I/M Pipeline  --  Simulation Start"));
		std.textio.writeline(std.textio.OUTPUT, L);
		std.textio.write(L, string'(" Monitoring SW stores and program completion..."));
		std.textio.writeline(std.textio.OUTPUT, L);
		std.textio.write(L, string'("================================================"));
		std.textio.writeline(std.textio.OUTPUT, L);

		-- Main simulation loop
		LOOP
			wait until rising_edge(clk_i);
			cycles := cycles + 1;

			-- Print every SW (store word to data memory)
			if MemWrite_ctrl_o = '1' then
				std.textio.write(L, string'("[SW] DTCM["));
				std.textio.write(L, ieee.std_logic_unsigned.CONV_INTEGER(dtcm_addr_o));
				std.textio.write(L, string'("] <= 0x"));
				ieee.std_logic_textio.hwrite(L, dtcm_data_wr_o);
				std.textio.write(L, string'("  (dec="));
				std.textio.write(L, ieee.std_logic_unsigned.CONV_INTEGER(dtcm_data_wr_o));
				std.textio.write(L, string'(")  cycle="));
				std.textio.write(L, cycles);
				std.textio.writeline(std.textio.OUTPUT, L);
			end if;

			-- Detect program completion: beq x0,x0,0 = 0x00000063
			if (WBinstruction_o = x"00000063") and (rst_i = '0') then
				std.textio.write(L, string'("================================================"));
				std.textio.writeline(std.textio.OUTPUT, L);
				std.textio.write(L, string'(" PROGRAM COMPLETED SUCCESSFULLY"));
				std.textio.writeline(std.textio.OUTPUT, L);
				std.textio.write(L, string'(" Total cycles  : "));
				std.textio.write(L, cycles);
				std.textio.writeline(std.textio.OUTPUT, L);
				std.textio.write(L, string'(" mclk_cnt      : "));
				std.textio.write(L, ieee.std_logic_unsigned.CONV_INTEGER(CLKCNT_o));
				std.textio.writeline(std.textio.OUTPUT, L);
				std.textio.write(L, string'(" STCNT         : "));
				std.textio.write(L, ieee.std_logic_unsigned.CONV_INTEGER(STCNT_o));
				std.textio.writeline(std.textio.OUTPUT, L);
				std.textio.write(L, string'(" FHCNT         : "));
				std.textio.write(L, ieee.std_logic_unsigned.CONV_INTEGER(FHCNT_o));
				std.textio.writeline(std.textio.OUTPUT, L);
				std.textio.write(L, string'("================================================"));
				std.textio.writeline(std.textio.OUTPUT, L);
				sim_done <= true;
				wait;  -- stop simulation
			end if;

			-- Timeout
			if cycles >= 50000 then
				report "TIMEOUT!" severity failure;
				wait;
			end if;
		END LOOP;
	END PROCESS;

END behavior;
