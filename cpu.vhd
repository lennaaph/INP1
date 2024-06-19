-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Thu Tra Phamová <xphamo00 AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
  ---PC---
  signal pc_reg: std_logic_vector (12 downto 0);
  signal pc_inc: std_logic; --0,1
  signal pc_dec: std_logic;
  
  ---PTR---
  signal ptr_reg: std_logic_vector (12 downto 0);
  signal ptr_inc: std_logic;
  signal ptr_dec: std_logic;

  ---CNT---
  signal cnt_reg: std_logic_vector (12 downto 0);
  signal cnt_inc: std_logic;
  signal cnt_dec: std_logic;

  ---MUX12---
  signal mx1_sel : std_logic;
  signal mx1_output : std_logic_vector (12 downto 0) := (others => '0');
  signal mx2_sel : std_logic_vector (1 downto 0) := (others => '0');
  signal mx2_output : std_logic_vector (7 downto 0) := (others => '0');

  ---STATES---
  type fsm_state is (
    state_start,
    state_fetch,
    state_decode,

    ---INSTRUCTIONS---
    point_inc,
    point_dec,

    prog_inc,
    prog_inc_wr,
    prog_inc_mx,

    prog_dec,
    prog_dec_wr,
    prog_dec_mx,

    while_start,
    while_start_if,
    while_start_search,
    while_start_do,
    
    while_end,
    while_end_if,
    while_end_do,
    while_end_search,
    
    do_while_start,
    do_while_start_if,
    do_while_start_do,
    do_while_start_loop,

    do_while_end,
    do_while_end_if,
    do_while_end_do,
    do_while_end_pc,
    do_while_end_loop,

    putchar_out,
    putchar_out_end,
    
    getchar_in,
    getchar_in_while,
    getchar_in_mx,
    null_return
  );

  ---FOR FSM---
  signal current_state : fsm_state := state_start;
  signal next_state : fsm_state;
 
begin
  ---PC---
  pc: process (CLK, RESET, pc_inc, pc_dec) is
  begin
    if RESET = '1' then
      pc_reg <= (others => '0');
    elsif rising_edge(CLK) then
      if pc_inc = '1' then
        pc_reg <= pc_reg + 1;
      elsif pc_dec = '1' then
        pc_reg <= pc_reg - 1;
      end if;
    end if;
  end process;

  ---PTR---
  ptr: process (CLK, RESET, ptr_inc, ptr_dec) is
  begin
    if RESET = '1' then
      ptr_reg <= "1000000000000";
    elsif rising_edge(CLK) then
      if ptr_inc = '1' then
        if ptr_reg = "1111111111111" then
          ptr_reg <= "1000000000000";
      	end if; 
	      ptr_reg <= ptr_reg + 1;
      elsif ptr_dec = '1' then
	      if ptr_reg = "1000000000000" then
          ptr_reg <= "1111111111111";
        end if;
          ptr_reg <= ptr_reg - 1;
        end if;
      end if;
  end process;
  
  ---CNT---
  cnt: process (CLK, RESET, cnt_inc, cnt_dec) is
  begin
    if RESET = '1' then
      cnt_reg <= (others => '0');
    elsif rising_edge(CLK) then
      if cnt_inc = '1' then
        cnt_reg <= cnt_reg + 1;
      elsif cnt_dec = '1' then
        cnt_reg <= cnt_reg - 1;
      end if;
    end if;
  end process;

  ---MX1---
  mx1: process (CLK, RESET, mx1_sel, pc_reg, ptr_reg) is
  begin
    if mx1_sel = '0' then
      mx1_output <= pc_reg;
    else
      mx1_output <= ptr_reg;
    end if;
  end process;
  DATA_ADDR <= mx1_output;

  ---MX2---
  mx2: process (CLK, RESET, IN_DATA, DATA_RDATA, mx2_sel) is
  begin
    if RESET = '1' then
      mx2_output <= (others => '0');
    elsif rising_edge(CLK) then
      case mx2_sel is
        when "00" =>
          mx2_output <= IN_DATA;
        when "01" =>
          mx2_output <= DATA_RDATA + 1;
        when "10" =>
          mx2_output <= DATA_RDATA - 1;
        when others =>
          mx2_output <= (others => '0');
      end case;
    end if;
  end process;
  DATA_WDATA <= mx2_output;
 
  ---FSM---
  fsm_logic: process (CLK, RESET, EN, current_state, next_state) is
  begin
    if RESET = '1' then
      current_state <= state_start;
    elsif rising_edge(CLK) then
      if EN = '1' then
        current_state <= next_state;
      end if;
    end if;
  end process;

  fsm: process (current_state, cnt_reg, OUT_BUSY, IN_VLD, DATA_RDATA, EN) is
  begin
    --- initialization ---
    pc_inc <= '0';
    pc_dec <= '0';
    ptr_inc <= '0';
    ptr_dec <= '0';
    cnt_inc <= '0';
    cnt_dec <= '0';

    DATA_EN <= '0';
    OUT_DATA <= "00000000";
    OUT_WE <= '0';
    DATA_RDWR <= '0';
    IN_REQ <= '0';
    
    mx1_sel <= '0';
    mx2_sel <= "00";
    
    case current_state is
      when state_start =>
        next_state <= state_fetch;
      when state_fetch =>
        DATA_EN <= '1';
        next_state <= state_decode;
      when state_decode =>
        case DATA_RDATA is
          when X"3E" =>
            next_state <= point_inc;
          when X"3C" =>
            next_state <= point_dec;
          when X"2B" =>
            next_state <= prog_inc;
          when X"2D" =>
            next_state <= prog_dec;
          when X"5B" =>
            next_state <= while_start;
          when X"5D" =>
            next_state <= while_end;
	        when X"28" =>
            next_state <= do_while_start;
	        when X"29" =>
            next_state <= do_while_end;
          when X"2E" =>
            next_state <= putchar_out;
          when X"2C" =>
            next_state <= getchar_in;
          when X"00" => 
            next_state <= null_return; 
          when others =>
            pc_inc <= '1';
            next_state <= state_fetch;
          end case ;
      ---   >   ---
      when point_inc =>
	      pc_inc <= '1';
        ptr_inc <= '1';
        next_state <= state_fetch;
      ---   <   ---
      when point_dec =>
	      pc_inc <= '1';
        ptr_dec <= '1';
        next_state <= state_fetch;
      ---   +   ---
      when prog_inc =>
	      mx1_sel <= '1';
	      DATA_EN <= '1';
        DATA_RDWR <= '0';
 	      next_state <= prog_inc_mx;
      when prog_inc_mx =>
        mx2_sel <= "01";
        next_state <= prog_inc_wr; 
      when prog_inc_wr =>
	      mx1_sel <= '1';
	      DATA_EN <= '1';
        DATA_RDWR <= '1';
        pc_inc <= '1';
        next_state <= state_fetch;
      ---   -   ---
      when prog_dec =>
        mx1_sel <= '1';
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= prog_dec_mx;
      when prog_dec_mx =>
        mx2_sel <= "10";
        next_state <= prog_dec_wr;
      when prog_dec_wr =>
        mx1_sel <= '1';
        DATA_EN <= '1';
        DATA_RDWR <= '1';
        pc_inc <= '1';
        next_state <= state_fetch;
      ---   [   ---
      when while_start =>
        pc_inc <= '1';
        mx1_sel <= '1';
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= while_start_if;
      when while_start_if =>
        if DATA_RDATA = "00000000" then
          cnt_inc <= '1';
	        mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
	        next_state <= while_start_do;
        else
          next_state <= state_fetch;
        end if;
      when while_start_do =>
	      if cnt_reg /= "0000000000000" then
          mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          next_state <= while_start_search;
	      else
	        next_state <= state_fetch;
	      end if;
      when while_start_search =>
        if DATA_RDATA = X"5B" then
          cnt_inc <= '1';
	      elsif DATA_RDATA = X"5D" then
      	  cnt_dec <= '1';
        end if;
      	pc_inc <= '1';
	      mx1_sel <= '0';
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= while_start_do;
      ---   ]   ---
      when while_end =>
        mx1_sel <= '1';
        DATA_EN <= '1';
        DATA_RDWR <= '0';
	      next_state <= while_end_if;
      when while_end_if =>
        if DATA_RDATA = "00000000" then
	        pc_inc <= '1';
          next_state <= state_fetch;
        else
	        cnt_inc <= '1';
          pc_dec <= '1';
	        mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          next_state <= while_end_do;
        end if;
      when while_end_do =>
	      if cnt_reg /= "0000000000000" then
          mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          next_state <= while_end_search;
        else
	        pc_inc <= '1';
          next_state <= state_fetch;
        end if;
      when while_end_search =>
	      if DATA_RDATA = X"5D" then
          cnt_inc <= '1';
        elsif DATA_RDATA = X"5B" then
          cnt_dec <= '1';
        end if;
	
	      if cnt_reg = "0000000000000" then
          pc_inc <= '1';
	      else
	        pc_dec <= '1';
      	end if;
        next_state <= while_end_do;
      ---   (   ---
      when do_while_start =>
        pc_inc <= '1';
        mx1_sel <= '1';
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= do_while_start_if;
      when do_while_start_if =>
        if DATA_RDATA = "00000000" then
	        mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          next_state <= do_while_start_do;
	      else
          next_state <= state_fetch;
        end if;
      when do_while_start_do =>
          if DATA_RDATA = X"28" then
            cnt_inc <= '1';
          elsif DATA_RDATA = X"29" then
            cnt_dec <= '1';
          end if;
          pc_inc <= '1';
          next_state <= do_while_start_loop;
      when do_while_start_loop =>
	      if cnt_reg /= "0000000000000" then
	        mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
	        next_state <= do_while_start_do;
	      else
	        next_state <= state_fetch;
	      end if;
      ---   )   ---
      when do_while_end =>
	      mx1_sel <= '1';
        DATA_EN <= '1';
        DATA_RDWR <= '0';
	      next_state <= do_while_end_if;
      when do_while_end_if =>
        if DATA_RDATA = "00000000" then
          pc_inc <= '1';
          next_state <= state_fetch;
        else
          pc_dec <= '1';
	        mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          next_state <= do_while_end_do;
        end if;
      when do_while_end_do =>
          if DATA_RDATA = X"29" then
            cnt_inc <= '1';
          elsif DATA_RDATA = X"28" then
            cnt_dec <= '1';
          end if;
          next_state <= do_while_end_pc;
      when do_while_end_pc =>
        if cnt_reg = "0000000000000" then
          pc_inc <= '1';
        else
          pc_dec <= '1';
        end if;
	        next_state <= do_while_end_loop;
      when do_while_end_loop =>
	      if cnt_reg /= "0000000000000" then
	        mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          next_state <= do_while_end_do;
	      else
	        next_state <= state_fetch;
	      end if;
      ---   .   ---
      when putchar_out =>
        mx1_sel <= '1';
        DATA_EN <= '1';
	      DATA_RDWR <= '0';
	      next_state <= putchar_out_end;
      when putchar_out_end =>
        mx1_sel <= '1';
        if OUT_BUSY = '1' then
	        DATA_EN <= '1';
          DATA_RDWR <= '0';
          next_state <= putchar_out_end;
        else
	        OUT_DATA <= DATA_RDATA;
          OUT_WE <= '1';
          pc_inc <= '1';
          next_state <= state_fetch;
        end if;
      ---   ,   ---
      when getchar_in =>
	      IN_REQ <= '1';
  	    mx1_sel <= '1';
    	  DATA_EN <= '1';
    	  DATA_RDWR <= '0';
	      next_state <= getchar_in_while;
      when getchar_in_while =>
      	mx1_sel <= '1';
	      if IN_VLD /= '1' then
	        IN_REQ <= '1';
	        DATA_EN <= '1';
	        DATA_RDWR <= '1';
          next_state <= getchar_in_while;
        else
	        next_state <= getchar_in_mx;
        end if;
      when getchar_in_mx =>
        mx2_sel <= "00";
	      mx1_sel <= '1';
	      DATA_EN <= '1';
	      DATA_RDWR <= '1';
	      pc_inc <= '1';
        next_state <= state_fetch;
      when null_return =>
	      next_state <= null_return;
    end case;
  end process;
end behavioral;
