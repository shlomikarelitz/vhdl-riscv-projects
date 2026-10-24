LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY load_store_unit IS
	PORT (
		data_addr_i     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		data_wdata_i    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		funct3_i        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
		
				-- Diagnostics / Assertions
		mem_read_i      : IN  STD_LOGIC;
		mem_write_i     : IN  STD_LOGIC;
		pc_i            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
		instruction_i   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
		
		-- DTCM read data
		dtcm_rdata_i    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		-- MMIO read data
		mmio_rdata_i    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		-- Region select (from router) to choose final load data
		mmio_sel_i      : IN  STD_LOGIC;
		
		-- DTCM Write outputs
		dtcm_byteena_o  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		dtcm_wdata_o    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		-- MMIO Write outputs
		mmio_wdata_o    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		-- Final Load Data back to write-back stage
		load_data_o     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END load_store_unit;

ARCHITECTURE behavior OF load_store_unit IS
	SIGNAL addr_offset   : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL b0, b1, b2, b3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL h0, h1         : STD_LOGIC_VECTOR(15 DOWNTO 0);
	
	SIGNAL dtcm_extracted_byte : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL dtcm_extracted_half : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL dtcm_extended_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
	
	SIGNAL extracted_byte      : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL extracted_half      : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL extended_data       : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN

	addr_offset <= data_addr_i(1 DOWNTO 0);

	-- =========================================================================
	-- STORE LOGIC (Generate byteena and align write data for DTCM)
	-- =========================================================================
	PROCESS(funct3_i, addr_offset, data_wdata_i)
	BEGIN
		-- Defaults
		dtcm_byteena_o <= "0000";
		dtcm_wdata_o <= (others => '0');
		
		IF funct3_i = "000" THEN -- SB
			CASE addr_offset IS
				WHEN "00" =>
					dtcm_byteena_o <= "0001";
					dtcm_wdata_o(7 DOWNTO 0) <= data_wdata_i(7 DOWNTO 0);
				WHEN "01" =>
					dtcm_byteena_o <= "0010";
					dtcm_wdata_o(15 DOWNTO 8) <= data_wdata_i(7 DOWNTO 0);
				WHEN "10" =>
					dtcm_byteena_o <= "0100";
					dtcm_wdata_o(23 DOWNTO 16) <= data_wdata_i(7 DOWNTO 0);
				WHEN "11" =>
					dtcm_byteena_o <= "1000";
					dtcm_wdata_o(31 DOWNTO 24) <= data_wdata_i(7 DOWNTO 0);
				WHEN OTHERS => NULL;
			END CASE;
		ELSIF funct3_i = "001" THEN -- SH
			IF addr_offset = "00" THEN
				dtcm_byteena_o <= "0011";
				dtcm_wdata_o(15 DOWNTO 0) <= data_wdata_i(15 DOWNTO 0);
			ELSIF addr_offset = "10" THEN
				dtcm_byteena_o <= "1100";
				dtcm_wdata_o(31 DOWNTO 16) <= data_wdata_i(15 DOWNTO 0);
			END IF;
		ELSIF funct3_i = "010" THEN -- SW
			dtcm_byteena_o <= "1111";
			dtcm_wdata_o <= data_wdata_i;
		ELSE
			-- Invalid funct3 for store, byteena must remain "0000"
			dtcm_byteena_o <= "0000";
		END IF;
	END PROCESS;

	-- MMIO write data is always right-aligned without lane shifting
	mmio_wdata_o <= data_wdata_i;

	-- =========================================================================
	-- LOAD LOGIC (Extract and Extend for DTCM and MMIO)
	-- =========================================================================
	b0 <= dtcm_rdata_i(7 DOWNTO 0);
	b1 <= dtcm_rdata_i(15 DOWNTO 8);
	b2 <= dtcm_rdata_i(23 DOWNTO 16);
	b3 <= dtcm_rdata_i(31 DOWNTO 24);
	
	h0 <= dtcm_rdata_i(15 DOWNTO 0);
	h1 <= dtcm_rdata_i(31 DOWNTO 16);
	
	dtcm_extracted_byte <= b0 WHEN addr_offset = "00" ELSE
	                       b1 WHEN addr_offset = "01" ELSE
	                       b2 WHEN addr_offset = "10" ELSE
	                       b3;
	                       
	dtcm_extracted_half <= h0 WHEN addr_offset = "00" ELSE h1;
	
	extracted_byte <= mmio_rdata_i(7 DOWNTO 0) WHEN mmio_sel_i = '1' ELSE dtcm_extracted_byte;
	extracted_half <= mmio_rdata_i(15 DOWNTO 0) WHEN mmio_sel_i = '1' ELSE dtcm_extracted_half;
	
	PROCESS(funct3_i, extracted_byte, extracted_half, dtcm_rdata_i, mmio_rdata_i, mmio_sel_i)
	BEGIN
		CASE funct3_i IS
			WHEN "000" => -- LB
				extended_data <= std_logic_vector(resize(signed(extracted_byte), 32));
			WHEN "100" => -- LBU
				extended_data <= std_logic_vector(resize(unsigned(extracted_byte), 32));
			WHEN "001" => -- LH
				extended_data <= std_logic_vector(resize(signed(extracted_half), 32));
			WHEN "101" => -- LHU
				extended_data <= std_logic_vector(resize(unsigned(extracted_half), 32));
			WHEN "010" => -- LW
				IF mmio_sel_i = '1' THEN
					extended_data <= mmio_rdata_i;
				ELSE
					extended_data <= dtcm_rdata_i;
				END IF;
			WHEN OTHERS =>
				IF mmio_sel_i = '1' THEN
					extended_data <= mmio_rdata_i;
				ELSE
					extended_data <= dtcm_rdata_i;
				END IF;
		END CASE;
	END PROCESS;

	-- Final load data output
	load_data_o <= extended_data;

	-- =========================================================================
	-- SIMULATION ASSERTIONS (Misaligned accesses and Invalid Funct3)
	-- =========================================================================
	-- pragma translate_off
	postponed PROCESS(data_addr_i, mem_read_i, mem_write_i, funct3_i)
	BEGIN
		IF (mem_read_i = '1' OR mem_write_i = '1') AND now > 0 ns AND (not is_x(data_addr_i)) AND (not is_x(funct3_i)) THEN
			-- Check for invalid funct3 for stores
			IF mem_write_i = '1' AND funct3_i /= "000" AND funct3_i /= "001" AND funct3_i /= "010" THEN
				assert false report "INVALID STORE FUNCT3: " & to_string(funct3_i) & 
				       " at PC=" & to_hstring(pc_i) & 
				       " inst=" & to_hstring(instruction_i) &
				       " addr=" & to_hstring(data_addr_i) &
				       " time=" & to_string(now)
				severity failure;
			END IF;
			
			-- Check for invalid funct3 for loads
			IF mem_read_i = '1' AND (funct3_i = "011" OR funct3_i = "110" OR funct3_i = "111") THEN
				assert false report "INVALID LOAD FUNCT3: " & to_string(funct3_i) & 
				       " at PC=" & to_hstring(pc_i) & 
				       " inst=" & to_hstring(instruction_i) &
				       " addr=" & to_hstring(data_addr_i) &
				       " time=" & to_string(now)
				severity failure;
			END IF;
			
			-- Misaligned Halfword access (LH/LHU/SH)
			IF mmio_sel_i = '0' AND (funct3_i = "001" OR (funct3_i = "101" AND mem_read_i = '1')) THEN
				assert (data_addr_i(0) = '0')
				report "MISALIGNED HALFWORD ACCESS: " & 
				       " funct3=" & to_string(funct3_i) & 
				       " at PC=" & to_hstring(pc_i) & 
				       " inst=" & to_hstring(instruction_i) &
				       " addr=" & to_hstring(data_addr_i) &
				       " time=" & to_string(now)
				severity failure;
			END IF;
			
			-- Misaligned Word access (LW/SW)
			IF mmio_sel_i = '0' AND funct3_i = "010" THEN
				assert (data_addr_i(1 DOWNTO 0) = "00")
				report "MISALIGNED WORD ACCESS: " & 
				       " funct3=" & to_string(funct3_i) & 
				       " at PC=" & to_hstring(pc_i) & 
				       " inst=" & to_hstring(instruction_i) &
				       " addr=" & to_hstring(data_addr_i) &
				       " time=" & to_string(now)
				severity failure;
			END IF;
		END IF;
	END PROCESS;
	-- pragma translate_on

END behavior;
