LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY hex_display_regs IS
	PORT (
		clk_i       : IN  STD_LOGIC;
		rst_i       : IN  STD_LOGIC;
		
		mem_write_i : IN  STD_LOGIC;
		wdata_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		cs_hex0_i   : IN  STD_LOGIC;
		cs_hex1_i   : IN  STD_LOGIC;
		cs_hex2_i   : IN  STD_LOGIC;
		cs_hex3_i   : IN  STD_LOGIC;
		cs_hex4_i   : IN  STD_LOGIC;
		cs_hex5_i   : IN  STD_LOGIC;
		
		hex0_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		hex1_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		hex2_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		hex3_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		hex4_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		hex5_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END hex_display_regs;

ARCHITECTURE structural OF hex_display_regs IS
	COMPONENT seven_segment_decoder
		PORT (
			data_i : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
			seg_o  : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
		);
	END COMPONENT;

	SIGNAL hex0_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex1_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex2_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex3_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex4_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex5_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN

	-- Registers
	PROCESS(clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			hex0_reg <= (others => '0');
			hex1_reg <= (others => '0');
			hex2_reg <= (others => '0');
			hex3_reg <= (others => '0');
			hex4_reg <= (others => '0');
			hex5_reg <= (others => '0');
		ELSIF rising_edge(clk_i) THEN
			IF mem_write_i = '1' THEN
				IF cs_hex0_i = '1' THEN hex0_reg <= wdata_i; END IF;
				IF cs_hex1_i = '1' THEN hex1_reg <= wdata_i; END IF;
				IF cs_hex2_i = '1' THEN hex2_reg <= wdata_i; END IF;
				IF cs_hex3_i = '1' THEN hex3_reg <= wdata_i; END IF;
				IF cs_hex4_i = '1' THEN hex4_reg <= wdata_i; END IF;
				IF cs_hex5_i = '1' THEN hex5_reg <= wdata_i; END IF;
			END IF;
		END IF;
	END PROCESS;

	-- Decoders (only lower 4 bits are fed to the decoder)
	dec0: seven_segment_decoder PORT MAP(data_i => hex0_reg(3 DOWNTO 0), seg_o => hex0_o);
	dec1: seven_segment_decoder PORT MAP(data_i => hex1_reg(3 DOWNTO 0), seg_o => hex1_o);
	dec2: seven_segment_decoder PORT MAP(data_i => hex2_reg(3 DOWNTO 0), seg_o => hex2_o);
	dec3: seven_segment_decoder PORT MAP(data_i => hex3_reg(3 DOWNTO 0), seg_o => hex3_o);
	dec4: seven_segment_decoder PORT MAP(data_i => hex4_reg(3 DOWNTO 0), seg_o => hex4_o);
	dec5: seven_segment_decoder PORT MAP(data_i => hex5_reg(3 DOWNTO 0), seg_o => hex5_o);

END structural;
