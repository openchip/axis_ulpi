library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_ulpi_v1_0 is
	generic (
		-- Users to add parameters here
        C_MODE	: integer	range 0 to 2 := 1; -- 0 RX only, 1 normal, 2 transmit only    

		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Parameters of Axi Slave Bus Interface S_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 8;

		-- Parameters of Axi Master Bus Interface M_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 8
	);
	port (
		-- Users to add ports here
		
		-- ULPI
		DATA_I	: in std_logic_vector(8-1 downto 0);
		DATA_O	: out std_logic_vector(8-1 downto 0);
		DATA_T	: out std_logic_vector(8-1 downto 0);
        CLK	    : in std_logic;
        DIR	    : in std_logic;
        NXT	    : in std_logic;
        STOP	: out std_logic;
        RST 	: out std_logic;

        -- ULPI RXCMD
        RXCMD_LS_DP : out std_logic;
        RXCMD_LS_DM : out std_logic;
        --
        RXCMD_VBUSVLD: out std_logic;
        RXCMD_SESSEND: out std_logic;
        RXCMD_SESSVLD: out std_logic;
        
        RXCMD_RXACTIVE: out std_logic;
        RXCMD_RXERROR: out std_logic;
        RXCMD_HDISCON: out std_logic;
        RXCMD_ID: out std_logic;
        RXCMD_ALTINTR: out std_logic;
        
        
        ULPI_CLKOUT    : out std_logic;
        ULPI_RSTBIN     : in std_logic;
        --
        mon_DIR	    : out std_logic;
        mon_NXT     : out std_logic;
        mon_STOP    : out std_logic;
        mon_RST    : out std_logic;

		mon_DATA	: out std_logic_vector(8-1 downto 0);
        
		-- User ports ends
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface S_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;
		s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

		-- Ports of Axi Master Bus Interface M_AXIS
		m_axis_aclk	: in std_logic;
		m_axis_aresetn	: in std_logic;
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		m_axis_tuser	: out std_logic;
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end axis_ulpi_v1_0;

architecture arch_imp of axis_ulpi_v1_0 is

signal DATA_iob : std_logic_vector(8-1 downto 0); -- latched in IOB
signal DIR_iob : std_logic; -- latched in IOB
signal NXT_iob : std_logic; -- latched in IOB

signal DIR_d : std_logic; -- delayed by 1
signal NXT_d : std_logic; -- delayed by 1- 
  		
signal STOP_i : std_logic; --   		

signal ULPI_DATA_O: std_logic_vector(8-1 downto 0);  		
signal RXCMD_i : std_logic_vector(8-1 downto 0);

signal ULPI_IDLE : std_logic; -- 
signal ULPI_IDLE_iob : std_logic; -- 

signal IDLE_last_cmd : std_logic; -- 1 if last TXCMD on bus was IDLE

signal RX_SOP : std_logic; -- 1 as long as first byte is received.. 


signal CLK_i : std_logic;


begin
    CLK_i <= CLK;
    ULPI_CLKOUT <= CLK_i;

-- latch everything in IOB
process (CLK_i)
begin  
   if (CLK_i'event and CLK_i = '0') then
        DATA_iob <= DATA_I;
        DIR_iob <= DIR;
        NXT_iob <= NXT;
   end if;
end process;

-- latch 
process (CLK_i)
begin  
   if (CLK_i'event and CLK_i = '1') then
        -- delayed vesions of 
        DIR_d <= DIR_iob;
        NXT_d <= NXT_iob;

        -- Turnaround done, NXT = 0 => RXCMD latch!
        -- only if TXCMD was ILDE!
        if (DIR_d = '1') and (DIR_iob = '1') and (NXT_iob = '0') and (ULPI_IDLE_iob='1') then
            RXCMD_i <= DATA_iob;
        end if;
   end if;
end process;

     
-- latch
process (CLK_i)
begin  
   if (CLK_i'event and CLK_i = '1') then
        if (DIR_d = '0') then
            RX_SOP <= '1';
        else
            if (NXT_iob = '1') then
                RX_SOP <= '0'; -- First byte of RX data received we clear start of packer flag
           end if;
        end if;
   end if;
end process;


    --
    m_axis_tdata <= DATA_iob; -- ?
    m_axis_tvalid <= DIR_d and DIR_iob and NXT_iob;
    m_axis_tuser <= RX_SOP;
    
             
    mon_DIR <= DIR_iob;
    mon_NXT <= NXT_iob;
    mon_DATA <= DATA_iob;


    RXCMD_LS_DP <= RXCMD_i(0); 
    RXCMD_LS_DM <= RXCMD_i(1);

    RXCMD_VBUSVLD <= RXCMD_i(3) and RXCMD_i(2); --11
    RXCMD_SESSEND <= not (RXCMD_i(3) and RXCMD_i(2)); -- 00
    RXCMD_SESSVLD <= RXCMD_i(3);
        
    RXCMD_RXACTIVE <= RXCMD_i(4);
    RXCMD_RXERROR <= RXCMD_i(5) and RXCMD_i(4); -- 11
    RXCMD_HDISCON <= RXCMD_i(5) and not RXCMD_i(4); -- 10

    
    RXCMD_ID <= RXCMD_i(6);
    RXCMD_ALTINTR <= RXCMD_i(7);


    STOP <= STOP_i;
    mon_STOP <= STOP_i;
    
process (CLK_i)
begin  
   if (ULPI_RSTBIN = '0') then
        STOP_i    <= '1';   
   elsif (CLK_i'event and CLK_i = '1') then
        if (DIR = '0') then
            STOP_i    <= '0';
        end if;
   end if;
end process;
    

    
    -----------------

    RST     <= ULPI_RSTBIN;
    mon_RST <= ULPI_RSTBIN;
    
    DATA_T  <= X"00" when DIR='0' else X"FF";


    ULPI_IDLE <= '1' when ULPI_DATA_O = X"00" else '0'; -- combinatorical IDLE
    ULPI_DATA_O <= s_axis_tdata;
    
process (CLK_i)
begin  
   if (CLK_i'event and CLK_i = '1') then
        DATA_O  <= ULPI_DATA_O;
        ULPI_IDLE_iob <= ULPI_IDLE; -- copy of IDLE at same clock as DIR_iob and NXT_iob
   end if;
end process;


    s_axis_tready <= '1';
    

end arch_imp;
