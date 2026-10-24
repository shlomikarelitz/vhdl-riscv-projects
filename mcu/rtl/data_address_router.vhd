LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY data_address_router IS
	PORT (
		data_addr_i     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		mem_read_i      : IN  STD_LOGIC;
		mem_write_i     : IN  STD_LOGIC;
		
		-- DTCM Interface
		dtcm_sel_o      : OUT STD_LOGIC;
		dtcm_read_o     : OUT STD_LOGIC;
		dtcm_write_o    : OUT STD_LOGIC;
		
		-- MMIO Interface
		mmio_sel_o      : OUT STD_LOGIC;
		mmio_read_o     : OUT STD_LOGIC;
		mmio_write_o    : OUT STD_LOGIC
	);
END data_address_router;

ARCHITECTURE structural OF data_address_router IS
	SIGNAL addr14      : STD_LOGIC_VECTOR(13 DOWNTO 0);
	SIGNAL dtcm_sel_w  : STD_LOGIC;
	SIGNAL mmio_sel_w  : STD_LOGIC;
BEGIN

	addr14 <= data_addr_i(13 downto 0);
	
	-- The architectural memory bus is 14 bits wide.  RARS-generated lecturer
	-- programs retain their conventional high data-segment base in registers,
	-- so selection intentionally uses the implemented low 14 address bits.
	dtcm_sel_w <= not addr14(13);
	mmio_sel_w <= addr14(13);

	dtcm_sel_o <= dtcm_sel_w;
	mmio_sel_o <= mmio_sel_w;
	
	dtcm_read_o  <= mem_read_i and dtcm_sel_w;
	dtcm_write_o <= mem_write_i and dtcm_sel_w;
	
	mmio_read_o  <= mem_read_i and mmio_sel_w;
	mmio_write_o <= mem_write_i and mmio_sel_w;

END structural;
