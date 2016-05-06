library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.all;
entity MIPS is
port(clk,reset : in std_logic;
	O1,O2,O3,O4 : out std_logic;
	P1,P2 : out std_logic
);
end MIPS;
architecture Behavioral of MIPS is
--type MEM2 is array(0 downto 4095) of std_logic_vector(7 downto 0);
type MEM1 is array(0 to 1023) of std_logic_vector(31 downto 0);
type REG is array(0 to 31) of std_logic_vector(31 downto 0);
signal Regt : REG := (others=>(x"00000000"));
signal IM : MEM1 := ("10001100000000010000000000000000","10001100000000100000000000001000","10001100000000110000000000000001","00000000001000100000100000100000","00000000010000110001000000100010","00010000000000100000000000000001","00001000000000000000000000000011",others=>(x"00000000"));
signal DM : MEM1 := (x"00000000",x"00000001",x"00000002",x"00000003",x"00000004",x"00000005",x"00000006",x"00000007",x"00000008",x"00000009",others=>(x"00000000"));
signal PC : std_logic_vector(31 downto 0) := (others=>'0');
signal IFID : std_logic_vector(63 downto 0) := (others=>'0');
signal IDEX :std_logic_vector(151 downto 0) := (others=>'0');
signal EXMEM : std_logic_vector(72 downto 0) := (others=>'0');
signal MEMWB : std_logic_vector(70 downto 0) := (others=>'0');
begin
	process(clk,reset)
	variable R : REG := (others=>(x"00000000"));
	variable IFIDR,IFIDL,IFIDS,IFIDB : std_logic;
	variable Stall,Zero,PCSrc,Jump,RegDst,ALUSrc,MemToReg,RegWrite,MemRead,MemWrite,Branch,ALUOp1,ALUOp0 : std_logic := '0';
	variable ALUOp,FA,FB : std_logic_vector(1 downto 0) := "00";
	variable ALUCS : std_logic_vector(3 downto 0) := "0000";
	variable Func : std_logic_vector(5 downto 0) := "000000";
	variable A,B,B1,R1,R2,SE,SESL,ALUR,PCB,PCJ,PCN : std_logic_vector(31 downto 0) := (others=>'0');
	variable PCI :integer := 0;
	begin
		if(reset='1')
		then
			PC<=(others=>'0');
			IFID<=(others=>'0');
			IDEX<=(others=>'0');
			EXMEM<=(others=>'0');
			MEMWB<=(others=>'0');
		elsif(clk='1' and clk'event)
		then
			--CU--
			RegDst:=not(IFID(31) or IFID(30) or IFID(29) or IFID(28) or IFID(27) or IFID(26));
			ALUSrc:=IFID(31) and not(IFID(30) or IFID(28)) and IFID(27) and IFID(26);
			MemToReg:=IFID(31) and not(IFID(30) or IFID(29) or IFID(28)) and IFID(27) and IFID(26);
			RegWrite:=not(IFID(30) or IFID(29) or IFID(28)) and ((IFID(31) and IFID(27) and IFID(26)) or not(IFID(31) or IFID(27) or IFID(26)));
			MemRead:=IFID(31) and not(IFID(30) or IFID(29) or IFID(28)) and IFID(27) and IFID(26);
			MemWrite:=IFID(31) and not(IFID(30) or IFID(28)) and IFID(29) and IFID(27) and IFID(26);
			Branch:=not(IFID(31) or IFID(30) or IFID(29) or IFID(27) or IFID(26)) and IFID(28);
			Jump:=not(IFID(31) or IFID(30) or IFID(29) or IFID(28) or IFID(26)) and IFID(27);
			ALUOp1:=not(IFID(31) or IFID(30) or IFID(29) or IFID(28) or IFID(26));
			ALUOp0:=not(IFID(31) or IFID(30) or IFID(29) or IFID(26)) and (IFID(28) xor IFID(27));

			--HDU--
			IFIDB:=Branch;
			IFIDR:=RegWrite and not(MemRead);
			IFIDL:=MemRead;
			IFIDS:=MemWrite;
			if(IDEX(151)='1' and IDEX(145)='1' and IFIDB='1' and (IDEX(4 downto 0)=IFID(25 downto 21) or (IDEX(4 downto 0)=IFID(20 downto 16))))
			then
				Stall:='1';
			elsif(IDEX(148)='1' and (IFIDL='1' or IFIDS='1') and IDEX(9 downto 5)=IFID(25 downto 21))
			then
				Stall:='1';
			elsif(IDEX(148)='1' and (IFIDR='1' or IFIDB='1') and (IDEX(9 downto 5)=IFID(25 downto 21) or IDEX(9 downto 5)=IFID(20 downto 16)))
			then
				Stall:='1';
			elsif(EXMEM(69)='1' and IFIDB='1' and (EXMEM(4 downto 0)=IFID(25 downto 21) or EXMEM(4 downto 0)=IFID(20 downto 16)))
			then
				Stall:='1';
			else
				Stall:='0';
			end if;
			--IF--
			if(Stall='0')
			then
				if(IDEX(143)='1')
				then
					PCN:=IDEX(142 downto 111);
				else
					PCN:=IFID(63 downto 32);
				end if;

				PCI:=conv_integer(PCN(9 downto 0));  ----Memory Restriction----
				IFID(31 downto 0)<=IM(PCI/4);
				IFID(63 downto 32)<=PCN+4;

				PC<=PCN;
			end if;
			--WB--
			R:=Regt;
			if(MEMWB(70)='1')
			then
				if(MEMWB(69)='0')
				then
					R(conv_integer(MEMWB(4 downto 0))):=MEMWB(36 downto 5);
				elsif(MEMWB(69)='1')
				then
					R(conv_integer(MEMWB(4 downto 0))):=MEMWB(68 downto 37);
				end if;
			end if;
			--ID--
			SE(15 downto 0):=IFID(15 downto 0);
			for i in 16 to 31
			loop
				SE(i):=IFID(15);
			end loop;
			SESL(1 downto 0):="00";
			for j in 0 to 29
			loop
				SESL(j+2):=SE(j);
			end loop;
			PCB:=IFID(63 downto 32) + SESL;
			PCJ(31 downto 28):=IFID(63 downto 60);
			PCJ(1 downto 0):="00";
			for k in 0 to 25
			loop
				PCJ(k+2):=IFID(k);
			end loop;
			if(Branch='1' and EXMEM(72)='1' and EXMEM(71)='0' and EXMEM(4 downto 0)=IFID(25 downto 21))
			then
				R1:=EXMEM(68 downto 37);
			else
				R1:=R(conv_integer(IFID(25 downto 21)));
			end if;
			if(Branch='1' and EXMEM(72)='1' and EXMEM(71)='0' and EXMEM(4 downto 0)=IFID(20 downto 16))
			then
				R2:=EXMEM(68 downto 37);
			else
				R2:=R(conv_integer(IFID(20 downto 16)));
			end if;
			if(R1=R2)
			then
				Zero:='1';
			else
				Zero:='0';
			end if;

			PCSrc:=(Zero and Branch) or Jump;
			if(Jump='1')
			then
				IDEX(142 downto 111)<=PCJ;
			elsif(JUMP='0')
			then
				IDEX(142 downto 111)<=PCB;
			end if;

			if(IDEX(143)='1' or Stall='1')
			then
				IDEX(151 downto 143)<="000000000";
			else
				IDEX(151)<=RegWrite;
				IDEX(150)<=MemToReg;
				IDEX(149)<=MemWrite;
				IDEX(148)<=MemRead;
				IDEX(147)<=ALUOp1;
				IDEX(146)<=ALUOp0;
				IDEX(145)<=RegDst;
				IDEX(144)<=AluSrc;

				IDEX(143)<=PCSrc;
			end if;
			IDEX(110 downto 79)<=R1;
			IDEX(78 downto 47)<=R2;
			IDEX(46 downto 15)<=SE;
			IDEX(14 downto 10)<=IFID(25 downto 21);
			IDEX(9 downto 5)<=IFID(20 downto 16);
			IDEX(4 downto 0)<=IFID(15 downto 11);
			Regt<=R;
			--EX--
			if(IDEX(145)='0')
			then
				EXMEM(4 downto 0)<=IDEX(9 downto 5);
			elsif(IDEX(145)='1')
			then
				EXMEM(4 downto 0)<=IDEX(4 downto 0);
			end if;
			--FU1--
			if(EXMEM(72)='1' and not(EXMEM(4 downto 0)="00000") and EXMEM(4 downto 0)=IDEX(14 downto 10))
			then
				FA:="10";
			elsif(MEMWB(70)='1' and not(EXMEM(4 downto 0)="00000") and MEMWB(4 downto 0)=IDEX(14 downto 10) and not(EXMEM(72)='1' and not(EXMEM(4 downto 0)=IDEX(14 downto 10))))
			then
				FA:="01";
			else
				FA:="00";
			end if;
			if(EXMEM(72)='1' and not(EXMEM(4 downto 0)="00000") and EXMEM(4 downto 0)=IDEX(9 downto 5))
			then
				FB:="10";
			elsif(MEMWB(70)='1' and not(EXMEM(4 downto 0)="00000") and MEMWB(4 downto 0)=IDEX(9 downto 5) and not(EXMEM(72)='1' and not(EXMEM(4 downto 0)=IDEX(9 downto 5))))
			then
				FB:="01";
			else
				FB:="00";
			end if;
			----
			ALUOp(1):=IDEX(147);
			ALUOp(0):=IDEX(146);
			Func:=IDEX(20 downto 15);
			if(ALUOp="00")
			then
				ALUCS:="0010";
			elsif(ALUOp="01")
			then
				ALUCS:="0110";
			elsif(ALUOp="10")
			then
				if(Func="100000")
				then
					ALUCS:="0010";
				elsif(Func="100010")
				then
					ALUCS:="0110";
				elsif(Func="100100")
				then
					ALUCS:="0000";
				elsif(Func="100101")
				then
					ALUCS:="0001";
				end if;
			end if;
			if(FA="00")
			then
				A:=IDEX(110 downto 79);
			elsif(FA="10")
			then
				A:=MEMWB(68 downto 37);
			elsif(FA="01")
			then
				A:=MEMWB(68 downto 37);
			end if;
			if(FB="00")
			then
				B1:=IDEX(78 downto 47);
			elsif(FB="10")
			then
				B1:=MEMWB(68 downto 37);
			elsif(FB="01")
			then
				B1:=MEMWB(68 downto 37);
			end if;
			if(IDEX(144)='0')
			then
				B:=B1;
			elsif(IDEX(144)='1')
			then
				B:=IDEX(46 downto 15);
			end if;
			if(ALUCS="0010")
			then
				ALUR:=A+B;
			elsif(ALUCS="0110")
			then
				ALUR:=A-B;
			elsif(ALUCS="0000")
			then
				ALUR:=A and B;
			elsif(ALUCS="0001")
			then
				ALUR:=A or B;
			end if;
			EXMEM(72)<=IDEX(151);
			EXMEM(71)<=IDEX(150);
			EXMEM(70)<=IDEX(149);
			EXMEM(69)<=IDEX(148);
			EXMEM(36 downto 5)<=B1;
			EXMEM(68 downto 37)<=ALUR;
			--MEM--
			MEMWB(70)<=EXMEM(72);
			MEMWB(69)<=EXMEM(71);
			MEMWB(4 downto 0)<=EXMEM(4 downto 0);
			MEMWB(36 downto 5)<=EXMEM(68 downto 37);
			if(EXMEM(70)='1')
			then
				if(MEMWB(70)='1' and MEMWB(69)='0' and EXMEM(70)='1' and EXMEM(4 downto 0)=MEMWB(4 downto 0))
				then
					DM(conv_integer(EXMEM(46 downto 37)))<=MEMWB(36 downto 5);   ----Memory Restriction----
				else
					DM(conv_integer(EXMEM(46 downto 37)))<=EXMEM(36 downto 5);  ----Memory Restriction----
				end if;
			elsif(EXMEM(69)='1')
			then
				MEMWB(68 downto 37)<=DM(conv_integer(EXMEM(68 downto 37)));
			end if;
			--**--
		end if;
		O1<=Stall;
		O2<=IFIDR;
		O3<=IFIDL;
		O4<=IFIDS;

		P2<=FA(1);

		P1<=FA(0);
	end process;
end Behavioral;