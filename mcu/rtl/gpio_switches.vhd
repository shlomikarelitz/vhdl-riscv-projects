LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY gpio_switches IS
	PORT (
		sw_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		rdata_o  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END gpio_switches;

ARCHITECTURE combinational OF gpio_switches IS
BEGIN
	-- Zero-extend the 8-bit switch input to 32 bits for the read data bus
	rdata_o(7 DOWNTO 0)  <= sw_i;
	rdata_o(31 DOWNTO 8) <= (others => '0');
END combinational;
