LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY gpio_ledr IS
	PORT (
		clk_i       : IN  STD_LOGIC;
		rst_i       : IN  STD_LOGIC;
		cs_i        : IN  STD_LOGIC;
		mem_write_i : IN  STD_LOGIC;
		wdata_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		ledr_o      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END gpio_ledr;

ARCHITECTURE behavior OF gpio_ledr IS
	SIGNAL ledr_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
	PROCESS(clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			ledr_reg <= (others => '0');
		ELSIF rising_edge(clk_i) THEN
			IF cs_i = '1' AND mem_write_i = '1' THEN
				ledr_reg <= wdata_i;
			END IF;
		END IF;
	END PROCESS;

	ledr_o <= ledr_reg;

END behavior;
