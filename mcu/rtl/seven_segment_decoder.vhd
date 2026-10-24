LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY seven_segment_decoder IS
	PORT (
		data_i : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
		seg_o  : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END seven_segment_decoder;

ARCHITECTURE combinational OF seven_segment_decoder IS
BEGIN
	-- Active-low 7-segment decoder
	-- seg_o(6) = G, seg_o(5) = F, ..., seg_o(0) = A
	PROCESS(data_i)
	BEGIN
		CASE data_i IS
			WHEN x"0" => seg_o <= "1000000"; -- 0
			WHEN x"1" => seg_o <= "1111001"; -- 1
			WHEN x"2" => seg_o <= "0100100"; -- 2
			WHEN x"3" => seg_o <= "0110000"; -- 3
			WHEN x"4" => seg_o <= "0011001"; -- 4
			WHEN x"5" => seg_o <= "0010010"; -- 5
			WHEN x"6" => seg_o <= "0000010"; -- 6
			WHEN x"7" => seg_o <= "1111000"; -- 7
			WHEN x"8" => seg_o <= "0000000"; -- 8
			WHEN x"9" => seg_o <= "0010000"; -- 9
			WHEN x"A" => seg_o <= "0001000"; -- A
			WHEN x"B" => seg_o <= "0000011"; -- B
			WHEN x"C" => seg_o <= "1000110"; -- C
			WHEN x"D" => seg_o <= "0100001"; -- D
			WHEN x"E" => seg_o <= "0000110"; -- E
			WHEN x"F" => seg_o <= "0001110"; -- F
			WHEN OTHERS => seg_o <= "1111111"; -- Off
		END CASE;
	END PROCESS;

END combinational;
