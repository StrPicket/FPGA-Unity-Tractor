library ieee;
use ieee.std_logic_1164.ALL;

entity bcd7seg_sec is 
	port(
		bcd: in std_logic_vector(3 downto 0);
		display: out std_logic_vector(7 downto 0)
	);
end entity;


architecture behavior of bcd7seg_sec is 
begin
	
	process (bcd)
	begin
		case bcd is 
			when "0000" =>
				display <= "11000000";
			when "0001" =>
				display <= "11111001";
			when "0010" =>
				display <= "10100100";
			when "0011" =>
				display <= "10110000";
			when "0100" =>
				display <= "10011001";
			when "0101" =>
				display <= "10010010";
			when "0110" =>
				display <= "10000010";
			when "0111" =>
				display <= "11111000";
			when "1000" =>
				display <= "10000000";
			when "1001" =>
				display <= "10011000";
			when "1010" =>
				display <= "10001000";
			when "1011" =>
				display <= "10000011";
			when "1100" =>
				display <= "10100111";
			when "1101" =>
				display <= "10100001";
			when "1110" =>
				display <= "10000110";
			when others =>
				display <= "10001110";	
		end case;
		
	end process;
	
end architecture;