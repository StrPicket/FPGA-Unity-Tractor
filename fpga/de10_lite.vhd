LIBRARY 	ieee;
USE		ieee.std_logic_1164.all;

ENTITY de10_lite IS
	GENERIC(
		d_width   :  INTEGER    := 8           --data bus width
);
	PORT(	CLOCK_50	: IN	std_logic;
		KEY		: IN	std_logic_vector(1 DOWNTO 0);
		GSENSOR_INT	: IN	std_logic_vector(1 DOWNTO 0);
		GSENSOR_SDI	: INOUT	std_logic;
		GSENSOR_SDO	: INOUT	std_logic;
		GSENSOR_CS_N	: OUT	std_logic;
		GSENSOR_SCLK	: OUT	std_logic;
		LEDR		: OUT	std_logic_vector(9 DOWNTO 0);
		botones : IN std_logic_vector(1 downto 0);
		switches: IN std_logic_vector(1 downto 0);
		tx: INOUT std_logic;
		rx: INOUT std_logic;
		display       :  OUT  STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END;

ARCHITECTURE Structural OF de10_lite IS

COMPONENT reset_delay IS
	PORT( 	iRSTN	: IN std_logic;
		iCLK	: IN std_logic;
		oRST	: OUT	std_logic
	);
END COMPONENT;

COMPONENT spi_pll IS
	PORT( 	areset	: IN std_logic;
		inclk0	: IN std_logic;
		c0	: OUT	std_logic;
		c1	: OUT std_logic
	);
END COMPONENT;


component bcd7seg_sec is 
	port(
		bcd: in std_logic_vector(3 downto 0);
		display: out std_logic_vector(7 downto 0)
	);
end component;

COMPONENT uart IS
  GENERIC(
    clk_freq  :  INTEGER    := 50_000_000;  --frequency of system clock in Hertz
    baud_rate :  INTEGER    := 115_200;      --data link baud rate in bits/second
    os_rate   :  INTEGER    := 16;          --oversampling rate to find center of receive bits (in samples per baud period)
    d_width   :  INTEGER    := 8;           --data bus width
    parity    :  INTEGER    := 0;           --0 for no parity, 1 for parity
    parity_eo :  STD_LOGIC  := '0');        --'0' for even, '1' for odd parity
  PORT(
    clk      :  IN   STD_LOGIC;                             --system clock
--    reset_n  :  IN   STD_LOGIC;                             --ascynchronous reset
    tx_ena   :  IN   STD_LOGIC;                             --initiate transmission
    tx_data  :  IN   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data to transmit
    rx       :  IN   STD_LOGIC;                             --receive pin
    rx_busy  :  OUT  STD_LOGIC;                             --data reception in progress
    rx_error :  OUT  STD_LOGIC;                             --start, parity, or stop bit error detected
    rx_data  :  OUT  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data received
    tx_busy  :  OUT  STD_LOGIC;                             --transmission in progress
    tx       :  OUT  STD_LOGIC);                            --transmit pin
END COMPONENT;

COMPONENT spi_ee_config IS
	PORT( 	iRSTN		: IN std_logic;
		iSPI_CLK	: IN std_logic;
		iSPI_CLK_OUT	: IN	std_logic;
		iG_INT2		: IN std_logic;
		oDATA_L		: OUT std_logic_vector(7 DOWNTO 0);
		oDATA_H		: OUT std_logic_vector(7 DOWNTO 0);
		SPI_SDIO	: INOUT std_logic;
		oSPI_CSN	: OUT std_logic;
		oSPI_CLK	: OUT std_logic
	);
END COMPONENT;
 
COMPONENT led_driver IS
	PORT( 	iRSTN	: IN std_logic;
		iCLK	: IN std_logic;
		iDIG	: IN std_logic_vector(9 DOWNTO 0);
		iG_INT2	: IN std_logic;
		oLED	: OUT std_logic_vector(9 DOWNTO 0)
	);
END COMPONENT;

SIGNAL dly_rst: std_logic;
SIGNAL spi_clk: std_logic;
SIGNAL spi_clk_out: std_logic;
SIGNAL data_x:	std_logic_vector(15 DOWNTO 0);
SIGNAL LEDR_2: std_logic_vector(9 DOWNTO 0);
SIGNAL tx_ena   :   STD_LOGIC;                             --initiate transmission
SIGNAL tx_data  :   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data to transmit
SIGNAL rx_busy  :   STD_LOGIC;                             --data reception in progress
SIGNAL rx_error :   STD_LOGIC;                             --start, parity, or stop bit error detected
SIGNAL rx_data  :   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data received
SIGNAL tx_busy  :   STD_LOGIC;                             --transmission in progress
SIGNAL inrx_data : STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);

SIGNAL LEDR_2_anterior	: std_logic_vector(9 DOWNTO 0) := (others => '0');
SIGNAL botones_anterior : std_logic_vector(1 downto 0) := (others => '0');
SIGNAL switches_anterior: std_logic_vector(1 downto 0) := (others => '0');


----Senales habilitadoras de UART
SIGNAL bt_uart: std_logic_vector(1 downto 0);
SIGNAL sw_uart: std_logic; -- 	inicializacion pendientes
SIGNAL ac_uart: std_logic;
SIGNAL test: std_logic := '0';

----Senales para el display 7seg
SIGNAL display_2: std_logic_vector(7 downto 0);


BEGIN

PROCESS(rx_busy)
	BEGIN
		IF(falling_edge (rx_busy)) THEN 
			inrx_data <= rx_data;
			
		END IF;
END PROCESS;

PROCESS(tx_busy)
	BEGIN
		IF(falling_edge (tx_busy)) THEN 
			test <= '1';
		END IF;		
END PROCESS;


PROCESS( CLOCK_50 )----botones

VARIABLE flag_bt :  std_logic_vector (1 downto 0) := "00";
VARIABLE flag_sw :  std_logic  := '0';
VARIABLE switches_prev :  std_logic_vector (1 downto 0) := "00";


BEGIN                                                                         
------------------------bt(0)----------------------------------
		IF rising_edge( CLOCK_50 ) THEN
			IF ( flag_bt(0) = '0' ) THEN
				IF ( botones(0) = '0' ) THEN
					bt_uart(0) <= '1';
					flag_bt(0) := '1';
				ELSE
					bt_uart(0) <= '0';
				END IF;
			ELSE
				bt_uart(0) <= '0';
				IF ( botones(0) = '1' ) THEN
					flag_bt(0) := '0';
				END IF;
			END IF;
------------------------bt(1)----------------------------------
			IF ( flag_bt(1) = '0' ) THEN
				IF ( botones(1) = '0' ) THEN
					bt_uart(1) <= '1';
					flag_bt(1) := '1';
				ELSE
					bt_uart(1) <= '0';
				END IF;
			ELSE
				bt_uart(1) <= '0';
				IF ( botones(1) = '1' ) THEN
					flag_bt(1) := '0';
				END IF;
			END IF;
		END IF;
END PROCESS;
-----------------------------------------------------


PROCESS( CLOCK_50 )----switches

VARIABLE flag_sw :  std_logic  := '0';
VARIABLE switches_prev :  std_logic_vector (1 downto 0) := "00";


BEGIN  
------------------------sw----------------------------------
      IF rising_edge( CLOCK_50 ) THEN
--		(switches(0) XOR switches_prev(0)) = '1') OR ((switches(1) XOR switches_prev(1)) = '1'
--	IF (switches = "01" or switches = "00" or switches = "11" or switches = "10" ) THEN
			IF ( flag_sw = '0' ) THEN
				IF (switches /= switches_prev) THEN
				--IF (switches = "01") THEN
				   --switches_prev := switches;
					sw_uart <= '1';
					flag_sw := '1';
				ELSE
					sw_uart <= '0';
				END IF;
			ELSE
				sw_uart <= '0';
				--switches(0) = switches_prev(0) AND switches(1) = switches_prev(1)
				IF (switches = switches_prev  ) THEN
					flag_sw := '0';
				END IF;
			END IF;	
-----------------------------------------------------
			switches_prev := switches;
		END IF;
END PROCESS;

	
PROCESS( CLOCK_50 )----Acelerometro
VARIABLE comp : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000001";
VARIABLE flag_ac :  std_logic  := '0';
VARIABLE state : INTEGER range 0 to 3 := 0; --CHECAR SI ESTA CORRECTO
VARIABLE state_prev : INTEGER range 0 to 3 := 0;
BEGIN  
------------------------ac----------------------------------
      IF rising_edge( CLOCK_50 ) THEN
			
			if(LEDR_2 < (comp(6 DOWNTO 0) & "000")) then
				state := 0;
			elsif(LEDR_2 > (comp(2 DOWNTO 0) & "0000000")) then
				state := 2;
			else
				state := 1;
			end if;
			
			IF ( flag_ac = '0' ) THEN
				IF (state /= state_prev) THEN
					ac_uart <= '1';
					flag_ac := '1';
				ELSE
					ac_uart <= '0';
				END IF;
			ELSE
				ac_uart <= '0';
				IF (state = state_prev) THEN
					flag_ac := '0';
				END IF;
			END IF;		
-----------------------------------------------------
		state_prev := state;
		END IF;
END PROCESS;	
				  
PROCESS(bt_uart, sw_uart, ac_uart)
--PROCESS( CLOCK_50 )
	VARIABLE comp : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000001";
	BEGIN
		--IF(botones /= botones_anterior) THEN
		--	tx_ena <= '0';
IF rising_edge( CLOCK_50 ) THEN	

	
		  IF(bt_uart(0)='1')THEN
			 tx_ena  <= '0';
			 --tx_data <= "01001011";
			 tx_data <= "01100001";
--		  ELSE
--			 if test = '1' THEN
--			   tx_ena <= '0';
--			   tx_data <= "01100010";
--				test_2 = '0';
--          ELSE 
--				tx_ena <= '1';
--			 END IF;
--		  END IF;
		  
		  ELSIF(bt_uart(1)='1')THEN
			 tx_ena  <= '0';
			 tx_data <= "01101011";
			 
		  ELSIF(sw_uart='1')THEN
			 CASE switches IS
					WHEN "10" => --P = 0X50
						tx_ena  <= '0';
						tx_data <= "01010000";
					WHEN "11" =>--N = 0x4E
						tx_ena  <= '0';
						tx_data <= "01001110";
					WHEN "01" =>--R = 0x52
						tx_ena  <= '0';
						tx_data <= "01010010";
					WHEN "00" =>--D =  0x44
						tx_ena  <= '0';
						tx_data <= "01000100";
					WHEN OTHERS =>
						tx_ena  <= '1';
						--tx_data <= "01011000"; -- Valor por defecto si ninguna condición es verdadera
				END CASE;
			ELSIF(ac_uart = '1') THEN
				if(LEDR_2 < (comp(6 DOWNTO 0) & "000")) then
					tx_ena  <= '0';
					tx_data <= "01110010";
				elsif(LEDR_2 > (comp(2 DOWNTO 0) & "0000000")) then
					tx_ena  <= '0';
					tx_data <= "01101100";
				else
					tx_ena  <= '0';
					tx_data <= "01011000"; -- ASCII = X
				end if;
			ELSE
				tx_ena <= '1';
		END IF;
		
end if;

END PROCESS;



LEDR <= LEDR_2;

display <= display_2;


				--Reset
reset		: reset_delay 	PORT MAP( KEY(0), CLOCK_50, dly_rst );

				--PLL
pll		: spi_pll 	PORT MAP( dly_rst, CLOCK_50, spi_clk, spi_clk_out );

				--Initial Setting and Data Read Back
spi_config	: spi_ee_config	PORT MAP( not dly_rst, spi_clk, spi_clk_out, GSENSOR_INT(0), data_x(7 DOWNTO 0), 
						data_x(15 DOWNTO 8), GSENSOR_SDI, GSENSOR_CS_N, GSENSOR_SCLK );

				--Led
led		: led_driver 	PORT MAP( not dly_rst, CLOCK_50, data_x(9 DOWNTO 0), GSENSOR_INT(0), LEDR_2 );

uartcom     :  uart   PORT MAP(CLOCK_50, tx_ena, tx_data, rx, rx_busy, rx_error, rx_data, tx_busy, tx);

display7seg : bcd7seg_sec PORT MAP(inrx_data(3 downto 0), display_2);

END Structural;