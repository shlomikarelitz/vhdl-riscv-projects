LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY mmio_address_decoder IS
	PORT (
		data_addr_i     : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
		mmio_sel_i      : IN  STD_LOGIC;
		mmio_read_i     : IN  STD_LOGIC;
		
		-- Read data inputs from peripherals
		sw_rdata_i      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		pb_rdata_i      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		ie_rdata_i      : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		ifg_rdata_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		type_rdata_i    : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		-- Timer read data inputs
		btctl1_i        : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		btctl2_i        : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		btcmpr0_i       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		btcmpr1_i       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		btcapr_i        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		-- Unified read data to LSU
		mmio_rdata_o    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		-- Chip selects
		cs_ledr_o       : OUT STD_LOGIC;
		cs_hex0_o       : OUT STD_LOGIC;
		cs_hex1_o       : OUT STD_LOGIC;
		cs_hex2_o       : OUT STD_LOGIC;
		cs_hex3_o       : OUT STD_LOGIC;
		cs_hex4_o       : OUT STD_LOGIC;
		cs_hex5_o       : OUT STD_LOGIC;
		cs_sw_o         : OUT STD_LOGIC;
		cs_pb_o         : OUT STD_LOGIC;
		cs_ie_o         : OUT STD_LOGIC;
		cs_ifg_o        : OUT STD_LOGIC;
		cs_type_o       : OUT STD_LOGIC;
		cs_btctl1_o     : OUT STD_LOGIC;
		cs_btctl2_o     : OUT STD_LOGIC;
		cs_btcmpr0_o    : OUT STD_LOGIC;
		cs_btcmpr1_o    : OUT STD_LOGIC;
		cs_btcapr_o     : OUT STD_LOGIC
	);
END mmio_address_decoder;

ARCHITECTURE combinational OF mmio_address_decoder IS
	SIGNAL addr : STD_LOGIC_VECTOR(13 DOWNTO 0);
	SIGNAL sel_ledr, sel_hex0, sel_hex1, sel_hex2, sel_hex3, sel_hex4, sel_hex5, sel_sw, sel_pb : STD_LOGIC;
	SIGNAL sel_ie, sel_ifg, sel_type : STD_LOGIC;
	SIGNAL sel_btctl1, sel_btctl2, sel_btcmpr0, sel_btcmpr1, sel_btcapr : STD_LOGIC;
	
	CONSTANT ADDR_IE       : STD_LOGIC_VECTOR(13 DOWNTO 0) := std_logic_vector(to_unsigned(16#202C#, 14));
	CONSTANT ADDR_IFG      : STD_LOGIC_VECTOR(13 DOWNTO 0) := std_logic_vector(to_unsigned(16#202D#, 14));
	CONSTANT ADDR_TYPE     : STD_LOGIC_VECTOR(13 DOWNTO 0) := std_logic_vector(to_unsigned(16#202E#, 14));
	CONSTANT ADDR_BTCTL1   : STD_LOGIC_VECTOR(13 DOWNTO 0) := std_logic_vector(to_unsigned(16#201C#, 14));
	CONSTANT ADDR_BTCTL2   : STD_LOGIC_VECTOR(13 DOWNTO 0) := std_logic_vector(to_unsigned(16#201D#, 14));
	CONSTANT ADDR_BTCMPR0  : STD_LOGIC_VECTOR(13 DOWNTO 0) := std_logic_vector(to_unsigned(16#2020#, 14));
	CONSTANT ADDR_BTCMPR1  : STD_LOGIC_VECTOR(13 DOWNTO 0) := std_logic_vector(to_unsigned(16#2024#, 14));
	CONSTANT ADDR_BTCAPR   : STD_LOGIC_VECTOR(13 DOWNTO 0) := std_logic_vector(to_unsigned(16#2028#, 14));
BEGIN
	addr <= data_addr_i;

	-- Address decoding based on the lower 14 bits of the address
	-- 0x2000 is 10 0000 0000 0000 in binary.
	
	sel_ledr <= '1' WHEN addr = "10000000000000" ELSE '0'; -- 0x2000
	sel_hex0 <= '1' WHEN addr = "10000000000100" ELSE '0'; -- 0x2004
	sel_hex1 <= '1' WHEN addr = "10000000000101" ELSE '0'; -- 0x2005
	sel_hex2 <= '1' WHEN addr = "10000000001000" ELSE '0'; -- 0x2008
	sel_hex3 <= '1' WHEN addr = "10000000001001" ELSE '0'; -- 0x2009
	sel_hex4 <= '1' WHEN addr = "10000000001100" ELSE '0'; -- 0x200C
	sel_hex5 <= '1' WHEN addr = "10000000001101" ELSE '0'; -- 0x200D
	sel_sw   <= '1' WHEN addr = "10000000010000" ELSE '0'; -- 0x2010
	sel_pb   <= '1' WHEN addr = "10000000010100" ELSE '0'; -- 0x2014
	
	sel_ie   <= '1' WHEN addr = ADDR_IE ELSE '0';
	sel_ifg  <= '1' WHEN addr = ADDR_IFG ELSE '0';
	sel_type <= '1' WHEN addr = ADDR_TYPE ELSE '0';
	
	sel_btctl1  <= '1' WHEN addr = ADDR_BTCTL1 ELSE '0';
	sel_btctl2  <= '1' WHEN addr = ADDR_BTCTL2 ELSE '0';
	sel_btcmpr0 <= '1' WHEN addr = ADDR_BTCMPR0 ELSE '0';
	sel_btcmpr1 <= '1' WHEN addr = ADDR_BTCMPR1 ELSE '0';
	sel_btcapr  <= '1' WHEN addr = ADDR_BTCAPR ELSE '0';

	-- Chip selects enabled only if mmio is selected
	cs_ledr_o <= sel_ledr AND mmio_sel_i;
	cs_hex0_o <= sel_hex0 AND mmio_sel_i;
	cs_hex1_o <= sel_hex1 AND mmio_sel_i;
	cs_hex2_o <= sel_hex2 AND mmio_sel_i;
	cs_hex3_o <= sel_hex3 AND mmio_sel_i;
	cs_hex4_o <= sel_hex4 AND mmio_sel_i;
	cs_hex5_o <= sel_hex5 AND mmio_sel_i;
	cs_sw_o   <= sel_sw   AND mmio_sel_i;
	cs_pb_o   <= sel_pb   AND mmio_sel_i;
	cs_ie_o   <= sel_ie   AND mmio_sel_i;
	cs_ifg_o  <= sel_ifg  AND mmio_sel_i;
	cs_type_o <= sel_type AND mmio_sel_i;
	
	cs_btctl1_o  <= sel_btctl1  AND mmio_sel_i;
	cs_btctl2_o  <= sel_btctl2  AND mmio_sel_i;
	cs_btcmpr0_o <= sel_btcmpr0 AND mmio_sel_i;
	cs_btcmpr1_o <= sel_btcmpr1 AND mmio_sel_i;
	cs_btcapr_o  <= sel_btcapr  AND mmio_sel_i;

	-- Read Multiplexer
	-- If mmio_read_i is active and cs_X_o is asserted, route X read data.
	-- Otherwise (for GPOs, write-only registers, or unmapped addresses), return 0.
	PROCESS(mmio_read_i, sel_sw, sel_pb, sel_ie, sel_ifg, sel_type, sel_btctl1, sel_btctl2, sel_btcmpr0, sel_btcmpr1, sel_btcapr, mmio_sel_i, sw_rdata_i, pb_rdata_i, ie_rdata_i, ifg_rdata_i, type_rdata_i, btctl1_i, btctl2_i, btcmpr0_i, btcmpr1_i, btcapr_i)
	BEGIN
		IF (mmio_read_i = '1' AND mmio_sel_i = '1') THEN
			IF sel_sw = '1' THEN
				mmio_rdata_o <= sw_rdata_i;
			ELSIF sel_pb = '1' THEN
				mmio_rdata_o <= pb_rdata_i;
			ELSIF sel_ie = '1' THEN
				mmio_rdata_o <= x"000000" & ie_rdata_i;
			ELSIF sel_ifg = '1' THEN
				mmio_rdata_o <= x"000000" & ifg_rdata_i;
			ELSIF sel_type = '1' THEN
				mmio_rdata_o <= x"000000" & type_rdata_i;
			ELSIF sel_btctl1 = '1' THEN
				mmio_rdata_o <= x"000000" & btctl1_i;
			ELSIF sel_btctl2 = '1' THEN
				mmio_rdata_o <= x"000000" & btctl2_i;
			ELSIF sel_btcmpr0 = '1' THEN
				mmio_rdata_o <= btcmpr0_i;
			ELSIF sel_btcmpr1 = '1' THEN
				mmio_rdata_o <= btcmpr1_i;
			ELSIF sel_btcapr = '1' THEN
				mmio_rdata_o <= btcapr_i;
			ELSE
				mmio_rdata_o <= (others => '0');
			END IF;
		ELSE
			mmio_rdata_o <= (others => '0');
		END IF;
	END PROCESS;

END combinational;
