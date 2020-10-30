library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    Port ( 
        i_clk     : in std_logic;
        i_start   : in std_logic;
        i_rst     : in std_logic;
        i_data    : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done    : out std_logic;
        o_en      : out std_logic;
        o_we      : out std_logic;
        o_data    : out std_logic_vector(7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    type state_type is (IDLE,           --initial state, waiting for start input
                        FETCH_DATA,     --getting data from the RAM
                        WAIT_RAM,       --waiting for RAM response
                        WAIT_RAM_2,
                        COMPUTE_OFFSET,      --write the result on the RAM
                        CHECK_ADDRESS,            --waiting for 'start' input to go down
                        WRITE_OUT,
                        DONE
                       );
    signal state, state_next : state_type := IDLE;
   
    type array_address is array(0 to 8) of std_logic_vector(7 downto 0);    
    signal array_wz   : array_address;
    
    signal rw_reg           :std_logic_vector(15 downto 0) := "0000000000000000";
    
    signal active : std_logic := '0';
    
    signal address_value    :std_logic_vector(7 downto 0) := (others => '0');
    signal wz_address       :integer range 0 to 7 := 0;
	signal address_offset   :integer :=127;

begin
    process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            active      <= '0';
            rw_reg      <= (others => '0');
            o_done      <= '0';
            state_next  <= IDLE;
            state       <= IDLE;
            
        elsif(i_start = '1' and active = '0') then                 --LEGGO L'INDIRIZZO BASE
            active <= '1';
            state_next <= WAIT_RAM;
            o_address  <= rw_reg;
            o_we <= '0';
            o_en <= '1';
                
        elsif(i_start = '0' and active = '1') then 
            active <= '0';
            state_next <= IDLE;
            o_done <= '0';
            
        elsif (i_clk'event and i_clk='1') then
            state <= state_next;
            if (state = state_next) then
                case state is
            
                    when WAIT_RAM => 
                        o_address <= rw_reg;
                        state_next <= WAIT_RAM_2;
                    when WAIT_RAM_2 =>
                        state_next <= FETCH_DATA;
                        
                    when FETCH_DATA =>
                        array_wz(conv_integer(rw_reg)) <= i_data;
                        
                        if (rw_reg = "0000000000001000") then     --leggo la prima wz
                            state_next <= COMPUTE_OFFSET;
                            wz_address <= 0;
                            
                        else                                            --calcolo l'offset
                            rw_reg      <= rw_reg + "0000000000000001";
                            state_next <= WAIT_RAM;
                        end if;
        
                    when COMPUTE_OFFSET =>
                        address_offset <= conv_integer (array_wz(8) - array_wz(wz_address));  --possibile overflow?
                        state_next <= CHECK_ADDRESS;
        
                    when CHECK_ADDRESS =>
                        if (address_offset >= 0 and address_offset <= 3) then
                            address_value <= std_logic_vector(shift_left(to_unsigned(wz_address,8), 4)(7 downto 0) + shift_left(to_unsigned(1,8), address_offset)(7 downto 0) + "10000000");
                            state_next <= WRITE_OUT;
        
                        elsif (wz_address = 7) then
                            address_value <= array_wz (8);
                            state_next <= WRITE_OUT;
                        else
                            wz_address <= wz_address + 1;
                            state_next <= COMPUTE_OFFSET;
                        end if;
                        
                        
                        
                    when WRITE_OUT =>
                        state_next  <= DONE;
                        o_address   <= "0000000000001001";
                        o_data      <= address_value;
                        o_we        <= '1';
                    
                
                    when IDLE =>
                    when DONE =>
                        o_done      <= '1';
                        state_next<=IDLE;
                end case;
            end if;
       end if;
    end process;       
end Behavioral;