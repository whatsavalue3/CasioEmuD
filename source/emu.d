module emu;
import std.stdio;
import std.format;

ubyte[0x8000] data;
ubyte[0x8000] cwiiram;
ubyte[0x80000] rom;
ubyte[0x1000] display;
ubyte[8] buttons;
uint PC = 0;
ubyte CSR = 0;
ubyte PSW = 0;
ushort SP = 0;
ushort EA = 0;
ubyte DSR = 0;
ushort ELR = 0;
ubyte ECSR = 0;
bool FLAG_DSR = false;
ubyte ADSR = 0;
bool HALT = false;
ubyte[16] REGS;
ubyte PSW_C = 0x80;
ubyte PSW_Z = 0x40;
ubyte PSW_S = 0x20;
ubyte PSW_OV = 0x10;
ubyte PSW_MIE = 0x08;
ubyte PSW_HC = 0x04;
ushort OP = 0;
bool ULTRAHALT = false;
uint lolcounter = 0;

ubyte ReadByte(uint of)
{
	ubyte seg = cast(ubyte)(of >>> 16);
	ushort addr = cast(ushort)of;
	if(seg == 0)
	{
		if(addr == 0xF410)
		{
			return 0x80 | data[addr & 0x7FFF];
		}
		if(addr == 0xF4AB)
		{
			return 0xF0;
		}
		if((addr&0xf800) == 0xf800)
		{
			return display[(addr&0x7ff) | (cast(ushort)(data[0x7037]&0x4)<<9)];
		}
		if(addr == 0xf040)
		{
			//ubyte pressedbutton = ((lolcounter&0x10) != 0) ? 0b10111111 : 0xff;
			//ubyte val = (data[0x7046] == 0x7f) ? pressedbutton : ((data[0x7046] == 0x8) ? pressedbutton : 0xff);
			
			//return val;
			ubyte ko = data[0x7046];
			ubyte ki = 0x0;
			for(int i = 0; i < 8; i++)
			{
				if(ko&(1<<i))
				{
					ki |= buttons[i];
				}
			}
			return cast(ubyte)(~ki);
		}
		if(addr >= 0x9000)
		{
			return data[addr&0x7fff];
		}
	}
	return rom[of&0x7ffff];
	/*
	if(seg == 8)
	{
		if(addr >= 0x8000)
		{
			if(addr < 0x9000)
			{
				return data[addr&0x7fff];
			}
			return cwiiram[addr&0x7fff];
		}
		return rom[addr];
	}
	return rom[of&0x7ffff];
	*/
}

ushort ReadCode(uint of)
{
	int seg = (of >>> 16) & 0xf;
	int addr = of & 0xFFFE;
	int indx = (seg << 16) | addr;
	if(indx >= 0x80000)
	{
		return 0xCEFF;
	}
	return cast(ushort)((cast(ushort)(rom[indx | 1]) << 8)) | cast(ushort)(rom[indx]);
}

ushort ReadWord(uint of)
{
	uint masked = of&0xfffffffe;
	return cast(ushort)((cast(ushort)ReadByte(masked)) | ((cast(ushort)ReadByte(masked|1))<<8));
}

uint ReadInt(uint of)
{
	return (cast(uint)ReadWord(of)) | ((cast(uint)ReadWord(of+2))<<16);
}

void WriteByte(uint of, ubyte b)
{
	ubyte seg = cast(ubyte)(of >>> 16);
	ushort addr = cast(ushort)of;
	
	if(seg == 0)
	{
		if((addr&0xf800) == 0xf800)
		{
			display[(addr&0x7ff) | (cast(ushort)(ReadByte(0xF037)&0x4)<<9)] = b;
		}
		if((addr&0x8000) != 0)
		{
			data[addr&0x7fff] = b;
		}
		else
		{
			writeln("BAD @","%x.%x".format(CSR,PC),": %x = %x".format(of,b));
			ULTRAHALT = true;
		}
		if((addr == 0xf009) && ((b&3) != 0))
		{
			//writeln("@","%x".format(PC-2),": %x = %x".format(of,b));
			HALT = true;
		}
		if(addr == 0xF000)
		{
			DSR = b;
		}
		//if(addr == 0xF037)
		//{
		//	writeln("@%x.%x:%x".format(CSR,PC-2,ELR),": %x = %x".format(of,b));
		//}
	}
	else if(seg == 8)
	{
		writeln("@","%x".format(PC-2),": Invalid Write 8:%x = %x".format(of,b));
		ULTRAHALT = true;
		if((addr&0x8000) != 0)
		{
			if(addr < 0x9000)
			{
				data[addr&0x7fff] = b;
			}
			else
			{
				cwiiram[addr&0x7fff] = b;
				
			}
		}
		else
		{
			writeln("@","%x".format(PC-2),": Invalid Write %x = %x".format(of,b));
			ULTRAHALT = true;
		}
	}
	else
	{
		writeln("@","%x".format(PC-2),": Invalid Write %x = %x".format(of,b));
		ULTRAHALT = true;
	}
}

void WriteWord(uint of, ushort val)
{
	uint masked = of&0xfffffffe;
	WriteByte(masked,cast(ubyte)val);
	WriteByte(masked|1,cast(ubyte)(val>>>8));
}

void WriteInt(uint of, uint val)
{
	WriteWord(of,cast(ushort)val);
	WriteWord(of+2,cast(ushort)(val>>>16));
}

ushort Fetch()
{
	PC &= 0xfffe;
	ushort op = ReadCode(cast(uint)(CSR<<16) | cast(uint)PC);
	PC += 2;
	return op;
}

bool IsFlagSet(ubyte flag)
{
	return (PSW & flag) != 0;
}

void SetFlag(ubyte flag, bool value)
{
	PSW &= ~flag;
	PSW |= value ? flag : 0;
}

bool FlagsCond(int p)
{
	int p1 = p & 0x0E;
	if(p1 == 0x00) {
		return IsFlagSet(PSW_C);
	}
	if(p1 == 0x02) {
		return IsFlagSet(PSW_Z) || IsFlagSet(PSW_C);
	}
	if(p1 == 0x04) {
		return IsFlagSet(PSW_OV) ^ IsFlagSet(PSW_S);
	}
	if(p1 == 0x06) {
		bool ovs = IsFlagSet(PSW_OV) ^ IsFlagSet(PSW_S);
		return ovs || IsFlagSet(PSW_Z);
	}
	if(p1 == 0x08) {
		return IsFlagSet(PSW_Z);
	}
	if(p1 == 0x0A) {
		return IsFlagSet(PSW_OV);
	}
	if(p1 == 0x0C) {
		return IsFlagSet(PSW_S);
	}
	if(p1 == 0x0E) {
		return false;
	}
	return false;
}

bool BranchFlags(ubyte p1)
{
	ubyte cond = FlagsCond(p1 & 0x0E) ? 1 : 0;
	return (p1 & 1) == cond;
}

bool Halfcarry(ubyte a, ubyte b, ubyte c)
{
	return ((a&0xf) + (b&0xf) + c) > 0xf;
}

bool Overflow(ubyte a, ubyte b, ubyte c)
{
	return ((a&0x7f) + (b&0x7f) + c) > 0x7f;
}

ubyte Add8(ubyte a, ubyte b, ubyte c = 0)
{
	uint ia = cast(uint)a;
	uint ib = cast(uint)b;
	uint result = ia+ib+cast(uint)c;
	SetFlag(PSW_HC, Halfcarry(a, b, c));
	SetFlag(PSW_OV, Overflow(a, b, c) ^ (result > 0xFF));
	SetFlag(PSW_C, result > 0xFF);
	return cast(ubyte)(result);
}

void Alu(ubyte t, ubyte reg, ubyte val)
{
	if(t == 0x00) {
		// MOV
		REGS[reg] = val;
		SetFlag(PSW_Z, REGS[reg] == 0);
		SetFlag(PSW_S, (REGS[reg] & 0x80) != 0);
		return;
	}
	if(t == 0x01) {
		// ADD Rn, val
		ubyte a = REGS[reg];
		ubyte result = Add8(a, val);
		REGS[reg] = result;
		SetFlag(PSW_Z, (result) == 0);
		SetFlag(PSW_S, (result & 0x80) != 0);
		return;
	}
	if(t == 0x02) {
		// AND Rn, val
		ubyte a = REGS[reg];
		ubyte result = (a & (val));
		REGS[reg] = result;
		SetFlag(PSW_Z, result == 0);
		SetFlag(PSW_S, (result & 0x80) != 0);
		return;
	}
	if(t == 0x03) {
		// OR Rn, val
		ubyte a = REGS[reg];
		ubyte result = (a | (val));
		REGS[reg] = result;
		SetFlag(PSW_Z, result == 0);
		SetFlag(PSW_S, (result & 0x80) != 0);
		return;
	}
	if(t == 0x04) {
		// XOR Rn, val
		ubyte a = REGS[reg];
		ubyte result = (a ^ (val));
		REGS[reg] = result;
		SetFlag(PSW_Z, result == 0);
		SetFlag(PSW_S, (result & 0x80) != 0);
		return;
	}
	if(t == 0x05) {
		// CMPC
		ubyte a = REGS[reg];
		ubyte result = 0xFF ^ Add8(0xFF ^ a, val, IsFlagSet(PSW_C) ? 1 : 0);
		bool prevZ = IsFlagSet(PSW_Z);
		SetFlag(PSW_Z, prevZ && ((result) == 0));
		SetFlag(PSW_S, (result & 0x80) != 0);
		return;
	}
	if(t == 0x06) {
		// ADC Rn, val
		ubyte a = REGS[reg];
		ubyte result = Add8(a, val, IsFlagSet(PSW_C) ? 1 : 0);
		REGS[reg] = result;
		bool prevZ = IsFlagSet(PSW_Z);
		SetFlag(PSW_Z, prevZ && ((result) == 0));
		SetFlag(PSW_S, (result & 0x80) != 0);
		return;
	}
	if(t == 0x07) {
		// CMP Rn, val
		ubyte a = REGS[reg];
		ubyte result = 0xFF ^ Add8(0xFF ^ a, val);
		SetFlag(PSW_Z, (result) == 0);
		SetFlag(PSW_S, (result & 0x80) != 0);
		return;
	}
	
}

void IncEA(int b)
{
	EA += b;
	int mask = 0xFFFFE | (b & 1);
	EA = (ushort)(EA & mask);
}

ubyte FetchDataByte(bool inc)
{
	ubyte dat = ReadByte((ADSR << 16) | EA);
	if(inc)
	{
		IncEA(1);
	}
	return dat;
}

ushort FetchDataWord(bool inc)
{
	ushort dat = ReadWord((ADSR << 16) | EA);
	if(inc)
	{
		IncEA(2);
	}
	return dat;
}

uint FetchDataInt(bool inc)
{
	uint dat = ReadInt((ADSR << 16) | EA);
	if(inc) 
	{
		IncEA(4);
	}
	return dat;
}

void FetchDataQR(ubyte r, bool inc)
{
	uint addr = cast(uint)((ADSR << 16) | (EA));
	uint a = ReadInt(addr);
	uint b = ReadInt(addr + 4);
	SetXRn(r, a);
	SetXRn(cast(byte)(r + 4), b);
	SetFlag(PSW_Z, (a | b) == 0);
	if(inc) EA += 8;
	return;
}

void DropByte(ubyte val, bool inc)
{
	uint addr = Seg(EA);
	WriteByte(addr, val);
	if(inc)
	{
		EA += 1;
	}
}

void DropShort(ushort val, bool inc)
{
	uint addr = Seg(EA);
	WriteWord(addr, val);
	if(inc)
	{
		EA += 2;
	}
}

void DropInt(uint val, bool inc)
{
	uint addr = Seg(EA);
	WriteInt(addr, val);
	if(inc)
	{
		EA += 4;
	}
}

void DropQR(ubyte r, bool inc)
{
	uint addr = Seg(EA);
	uint a = GetXRN(r);
	uint b = GetXRN(cast(ubyte)(r + 4));
	WriteInt(addr, a);
	WriteInt(addr + 4, b);
	if(inc)
	{
		EA += 8;
	}
}


ubyte PopByte()
{
	ubyte value = ReadByte(SP);
	SP += 2;
	return value;
}

ushort PopWord()
{
	ushort value = ReadWord(SP);
	SP += 2;
	return value;
}

uint PopInt()
{
	uint value = ReadInt(SP);
	SP += 4;
	return value;
}

void PushByte(ubyte val)
{
	SP -= 2;
	WriteByte(SP, val);
}

void PushInt(uint val)
{
	SP -= 4;
	WriteInt(SP, val);
}

void PushWord(ushort val)
{
	SP -= 2;
	WriteWord(SP, val);
}

void SetERn(ubyte r, ushort val)
{
	r = r & 0x0E;
	REGS[r] = val & 0xFF;
	REGS[r + 1] = (val & 0xFF00) >>> 8;
}

void SetXRn(ubyte r, uint val)
{
	SetERn(r&0x0C,cast(ushort)val);
	SetERn(r|2,cast(ushort)(val >>> 16));
}

void LoadERn(ubyte r, ushort val)
{
	SetERn(r, val);
	SetFlag(PSW_Z, val == 0);
	SetFlag(PSW_S, (val & 0x8000) != 0);
}

void LoadXRn(ubyte r, uint val)
{
	SetXRn(r, val);
	SetFlag(PSW_Z, val == 0);
	SetFlag(PSW_S, (val & 0x80000000) != 0);
}


void LoadRegister(ubyte r, ubyte val)
{
	REGS[r] = val;
	SetFlag(PSW_Z, val == 0);
	SetFlag(PSW_S, (val & 0x80) != 0);
}

void DsrPrefix(ubyte v)
{
	DSR = v;
	FLAG_DSR = true;
}

uint Seg(ushort addr)
{
	return ((cast(uint)ADSR) << 16) | cast(uint)addr;
}

ushort Add16(ushort a, ushort b)
{
	ubyte al = cast(ubyte)a;
	ubyte bl = cast(ubyte)b;
	ubyte resultL = Add8(al, bl);
	ubyte ah = cast(ubyte)(a >>> 8);
	ubyte bh = cast(ubyte)(b >>> 8);
	ubyte resultH = Add8(ah, bh, IsFlagSet(PSW_C) ? 1 : 0);
	return ((cast(ushort)resultH) << 8) | (cast(ushort)resultL);
}

ushort GetERN(ubyte reg)
{
	return (cast(ushort)(REGS[reg&0xe])) | (((cast(ushort)(REGS[(reg&0xe)|1]))<<8));
}

uint GetXRN(ubyte reg)
{
	return cast(uint)(GetERN(reg&0xc)) | ((cast(uint)(GetERN(reg|2)))<<16);
}

void OP_Add16(ubyte reg, ushort val)
{
	ushort a = GetERN(reg);
	ushort result = Add16(a, val);
	SetFlag(PSW_Z, result == 0);
	SetFlag(PSW_S, (result & 0x8000) != 0);
	SetERn(reg, result);
}

ushort Mul88(ubyte a, ubyte b)
{
	ushort result = cast(ushort)(a * b);
	SetFlag(PSW_Z, result == 0);
	return result;
}

void Mov16(ubyte reg, ushort val)
{
	SetERn(reg, val);
	SetFlag(PSW_Z, val == 0);
	SetFlag(PSW_S, (val & 0x8000) != 0);
}

short Disp6(ubyte p23)
{
	short imm6 = cast(short)(p23 & 0x3F);
	if((imm6 & 0x20) != 0) {
		imm6 |= 0xFFFF ^ 0x3F;
	}
	return imm6;
}

void Cmp16(ubyte reg, ushort val)
{
	ushort a = GetERN(reg);
	ushort result = 0xFFFF ^ Add16(0xFFFF ^ a, val);
	SetFlag(PSW_Z, (result) == 0);
	SetFlag(PSW_S, (result & 0x8000) != 0);
}

void Alu_Sub8(ubyte reg, ubyte val)
{
	ubyte a = REGS[reg];
	ubyte result = 0xFF ^ Add8(0xFF ^ a, val);
	REGS[reg] = result;
	SetFlag(PSW_Z, (result) == 0);
	SetFlag(PSW_S, (result & 0x80) != 0);
}

void Alu_Sbc8(ubyte reg, ubyte val)
{
	ubyte a = REGS[reg];
	ubyte result = 0xFF ^ Add8(0xFF ^ a, val, IsFlagSet(PSW_C) ? 1 : 0);
	REGS[reg] = result;
	bool prevZ = IsFlagSet(PSW_Z);
	SetFlag(PSW_Z, prevZ && ((result) == 0));
	SetFlag(PSW_S, (result & 0x80) != 0);
}

void SLLC(ubyte reg, ubyte val)
{
	val &= 7;
	ubyte a = REGS[reg];
	uint b0 = cast(uint)REGS[(reg - 1) & 0x0F] << val;
	uint b = b0 >>> 8;
	uint result = (cast(uint)a) << val;
	SetFlag(PSW_C, (result & 0x100) != 0);
	REGS[reg] = cast(ubyte)(result | b);
}

void SLL(ubyte reg, ubyte val)
{
	val &= 7;
	ubyte a = REGS[reg];
	uint result = (cast(uint)a) << val;
	SetFlag(PSW_C, (result & 0x100) != 0);
	REGS[reg] = cast(ubyte)(result);
}

void Div(ubyte ern, ubyte rm)
{
	ushort a = GetERN(ern);
	ubyte b = REGS[rm];
	SetFlag(PSW_C, b == 0);
	if(b == 0)
	{
		return;
	}
	ubyte mod = cast(ubyte)(a % b);
	ushort div = cast(ushort)(a / b);
	SetFlag(PSW_Z, div == 0);
	SetERn(ern, div);
	REGS[rm] = mod;
}

void SRLC(ubyte reg, ubyte val)
{
	val &= 7;
	uint b0 = cast(uint)REGS[(reg + 1) & 0x0F] << 8;
	uint b = (b0 >>> val);
	uint a = cast(uint)(REGS[reg]) << 1;
	uint result = a >>> val;
	SetFlag(PSW_C, (result & 0x1) != 0);
	REGS[reg] = cast(ubyte)(b | (result >>> 1));
}
void SRL(ubyte reg, ubyte val)
{
	val &= 7;
	uint a = cast(uint)(REGS[reg]) << 1;
	uint result = a >>> val;
	SetFlag(PSW_C, (result & 0x1) != 0);
	REGS[reg] = cast(ubyte)(result >>> 1);
}

void SRA(ubyte reg, ubyte val)
{
	val &= 7;
	uint a = cast(uint)(REGS[reg]) << 1;
	uint carry = a >>> val;
	SetFlag(PSW_C, (carry & 0x1) != 0);
	REGS[reg] = cast(ubyte)((cast(byte)REGS[reg]) >> val);
}

ubyte Inc8(ubyte a)
{
	uint result = a + 1;
	SetFlag(PSW_HC, Halfcarry(a, 1, 0));
	SetFlag(PSW_OV, Overflow(a, 1, 0) ^ (result > 0xFF));
	SetFlag(PSW_C, result > 0xFF);
	return cast(ubyte)(result);
}

ubyte Op_Inc8(ubyte val)
{
	ubyte result = Inc8(val);
	SetFlag(PSW_Z, result == 0);
	SetFlag(PSW_S, (result & 0x80) != 0);
	return result;
}

ubyte Dec8(ubyte val)
{
	ubyte result = 0xFF ^ Inc8(val ^ 0xFF);
	SetFlag(PSW_Z, result == 0);
	SetFlag(PSW_S, (result & 0x80) != 0);
	return result;
}

void Daa8(ubyte reg)
{
	ubyte val = REGS[reg];
	ubyte l = val & 0x0F;
	ubyte h = (val & 0xF0) >>> 4;
	bool hc = IsFlagSet(PSW_HC);
	bool carry = IsFlagSet(PSW_C);
	bool ov_prev = IsFlagSet(PSW_OV);
	ubyte offset = 0x00;
	if(hc || (l > 0x09)) {
		offset |= 0x06;
	}
	if(carry || (h > 0x09)) {
		offset |= 0x60;
	}
	bool nc = !hc;
	if((h == 9) && (l > 0x09) && nc) {
		offset |= 0x60;
	}
	Alu(1, reg, offset);
	if(carry)
	{
		SetFlag(PSW_C,true);
	}
	SetFlag(PSW_OV, ov_prev);
}

void Das8(ubyte reg)
{
	ubyte val = REGS[reg];
	ubyte l = val & 0x0F;
	ubyte h = (val & 0xF0) >>> 4;
	bool hc = IsFlagSet(PSW_HC);
	bool carry = IsFlagSet(PSW_C);
	bool ov_prev = IsFlagSet(PSW_OV);
	ubyte offset = 0x00;
	if(hc || (l > 0x09)) {
		offset |= 0x06;
	}
	if(carry || (h > 0x09)) {
		offset |= 0x60;
	}
	Alu_Sub8(reg, offset);
	if(carry)
	{
		SetFlag(PSW_C,true);
	}
	SetFlag(PSW_OV, ov_prev);
}

ubyte Neg8(ubyte val)
{
	ubyte result = 0xFF ^ Add8(0xFF, val);
	SetFlag(PSW_Z, (result) == 0);
	SetFlag(PSW_S, (result & 0x80) != 0);
	return (result);
}

void Execute(ushort op)
{
	OP = op;
	ubyte p0 = cast(ubyte)(op>>>12);
	ubyte p1 = cast(ubyte)(op>>>8)&0xf;
	ubyte p2 = cast(ubyte)(op>>>4)&0xf;
	ubyte p3 = cast(ubyte)op&0xf;
	ubyte p23 = cast(ubyte)op;
	if(SP < 0x8000)
	{
		ULTRAHALT = true;
		writeln("STACK OUT OF BOUNDS: %x".format(SP));
		return;
	}
	//

	//writeln("@","%x".format(PC-2),": %x".format(op));
	if(p0 == 0x0C)
	{
		if(BranchFlags(p1))
		{
			int off = cast(byte)p23;
			PC += (off << 1);
		}
		return;
	}
	if((p0 & 0x8) == 0)
	{
		Alu(p0,p1,p23);
		return;
	}
	if(p0 == 0x08)
	{
		if((p3 & 0x08) == 0)
		{
			Alu(p3, p1, REGS[p2]);
			return;
		}
		
		if(p3 == 0x08)
		{
			Alu_Sub8(p1, REGS[p2]);
			return;
		}
		
		if((op & 0xF11F) == 0x810F)
		{
			SetERn(p2, cast(ushort)(REGS[p2]));
			return;
		}
		if(p3 == 0x09)
		{
			Alu_Sbc8(p1, REGS[p2]);
			return;
		}

		if(p3 == 0x0A) {
			SLL(p1, REGS[p2]);
			return;
		}
		if(p3 == 0x0B) {
			SLLC(p1, REGS[p2]);
			return;
		}
		if(p3 == 0x0C) {
			SRL(p1, REGS[p2]);
			return;
		}
		if(p3 == 0x0D) {
			SRLC(p1, REGS[p2]);
			return;
		}
		if(p3 == 0x0E) {
			SRA(p1, REGS[p2]);
			return;
		}
		if((op & 0xF0FF) == 0x801F)
		{
			Daa8(p1);
			return;
		}
		if((op & 0xF0FF) == 0x803F)
		{
			Das8(p1);
			return;
		}
		if((op & 0xF0FF) == 0x805F)
		{
			REGS[p1] = Neg8(REGS[p1]);
			return;
		}
	}
	
	if(p0 == 0x0F)
	{
		if(op == 0xF00C)
		{
			EA = Fetch();
			return;
		}
		if((op & 0xF00F) == 0xF004)
		{
			ubyte a = REGS[p1];
			ubyte b = REGS[p2];
			SetERn(p1, Mul88(a, b));
			return;
		}
		if((op & 0xFF1F) == 0xF00A) 
		{
			EA = GetERN(p2);
			return;
		}
		if((op & 0xF0FE) == 0xF000)
		{
			ushort cadr = Fetch();
			if((p3 & 1) == 0x01)
			{
				ELR = cast(ushort)PC;
				ECSR = CSR;
			}
			PC = cadr;
			CSR = p1;
			return;
		}
		if(op == 0xFE1F)
		{
			PC = cast(uint)ELR;
			CSR = ECSR;
			return;
		}
		if((op & 0xF0FF) == 0xF0CE)
		{
			if((p1 & 2) != 0)
			{
				writeln("@","%x".format(PC-2),": %x  unimplemented ECSR ELR".format(op));
				ULTRAHALT = true;
				return;
				//ubyte elvl = PSW&0x3;
				//PushWord(ECSR[elvl]);
				//PushWord(ELR[elvl]);
			}
			if((p1 & 4) != 0)
			{
				PushByte(PSW);
			}
			if((p1 & 8) != 0)
			{
				PushByte(ECSR);
				PushWord(ELR);
			}
			if((p1 & 1) != 0)
			{
				PushWord(EA);
			}
			return;
			
		}
		if((op & 0xF11F) == 0xF005)
		{
			Mov16(p1, GetERN(p2));
			return;
		}
		if(op == 0xFE8F)
		{
			return;
		}
		if((op & 0xF0FF) == 0xF08E)
		{
			if((p1 & 1) != 0)
			{
				EA = PopWord();
			}
			if((p1 & 8) != 0)
			{
				ELR = PopWord();
				ECSR = PopByte();
				
			}
			if((p1 & 4) != 0)
			{
				PSW = PopByte();
			}
			if((p1 & 2) != 0)
			{
				PC = PopWord();
				CSR = PopByte();
			}
			return;
		}
		if((op & 0xF1FF) == 0xF05E)
		{
			PushWord(GetERN(p1));
			return;
		}
		if((op & 0xF1FF) == 0xF01E)
		{
			SetERn(p1, PopWord());
			return;
		}
		if((op & 0xF3FF) == 0xF06E)
		{
			PushInt(GetXRN(p1));
			return;
		}
		if((op & 0xF11F) == 0xF006)
		{
			OP_Add16(p1, GetERN(p2));
			return;
		}
		if((op & 0xF11F) == 0xF007)
		{
			Cmp16(p1, GetERN(p2));
			return;
		}
		if((op & 0xF3FF) == 0xF02E)
		{
			SetXRn(p1, PopInt());
			return;
		}
		if((op & 0xF7FF) == 0xF07E) 
		{
			PushInt(GetXRN(cast(ubyte)(p1 + 4)));
			PushInt(GetXRN(p1));
			return;
		}
		if((op & 0xF7FF) == 0xF03E)
		{
			uint val = PopInt();
			uint val2 = PopInt();
			SetXRn(p1, val);
			SetXRn(cast(ubyte)(p1 + 4), val2);
			
			return;
		}
		if((op & 0xF0FF) == 0xF04E)
		{
			PushByte(REGS[p1]);
			return;
		}
		if((op & 0xF10F) == 0xF009)
		{
			Div(p1, p2);
			return;
		}
		if((op & 0xF0FF) == 0xF00E)
		{
			REGS[p1] = PopByte();
			return;
		}
		if((op & 0xFF1F) == 0xF00B)
		{
			EA = cast(ushort)(GetERN(p2) + cast(ushort)Fetch());
			return;
		}
		if(op == 0xFE2F)
		{
			ubyte val = FetchDataByte(false);
			DropByte(Op_Inc8(val), false);
			return;
		}
		if(op == 0xFE3F)
		{
			ubyte val = FetchDataByte(false);
			DropByte(Dec8(val), false);
			return;
		}
		if(op == 0xFE9F)
		{
			FLAG_DSR = true;
			return;
		}
		if((op & 0xFF1E) == 0xF002)
		{
			ushort cadr = GetERN(p2);
			if((p3 & 1) == 0x01)
			{
				ELR = cast(ushort)PC;
				ECSR = CSR;
			}
			PC = cadr;
			return;
		}
		//if((op & 0xF0FF) == 0x805F)
		//{
		//	int val = this.neg8(this.getRegister(p1));
		//	this.setRegister(p1, val);
		//	return;
		//}
		
	}
	
	if(p0 == 0x09)
	{
		if((op & 0xFF0F) == 0x900F)
		{
			DsrPrefix(REGS[p2]);
			return;
		}
		if((op & 0xF1FF) == 0x9052)
		{
			ushort val = FetchDataWord(true);
			LoadERn(p1, val);
			return;
		}
		if((op & 0xF0FF) == 0x9050) 
		{
			ubyte val = FetchDataByte(true);
			LoadRegister(p1, val);
			return;
		}
		if((op & 0xF11F) == 0x9002) 
		{
			uint erm = Seg(GetERN(p2));
			ushort val = ReadWord(erm);
			LoadERn(p1, val);
			return;
		}
		if((op & 0xF11F) == 0x9003) 
		{
			uint erm = Seg(GetERN(p2));
			WriteWord(erm, GetERN(p1));
			return;
		}
		if((op & 0xF0FF) == 0x9011)
		{
			ushort addr = Fetch();
			WriteByte(Seg(addr), REGS[p1]);
			return;
		}
		if((op & 0xF0FF) == 0x9010)
		{
			uint addr = Seg(Fetch());
			LoadRegister(p1, ReadByte(addr));
			return;
		}
		if((op & 0xF1FF) == 0x9013)
		{
			ushort addr = Fetch();
			WriteWord(Seg(addr), GetERN(p1));
			return;
		}
		if((op & 0xF01F) == 0x9000)
		{
			uint erm = Seg(GetERN(p2));
			ubyte val = ReadByte(erm);
			LoadRegister(p1, val);
			return;
		}
		if((op & 0xF01F) == 0x9001)
		{
			uint erm = Seg(GetERN(p2));
			WriteByte(erm, REGS[p1]);
			return;
		}
		if((op & 0xF1FF) == 0x9053)
		{
			DropShort(GetERN(p1), true);
			return;
		}
		if((op & 0xF3FF) == 0x9055)
		{
			DropInt(GetXRN(p1), true);
			return;
		}
		if((op & 0xF08F) == 0x900B)
		{
			SLLC(p1, p2);
			return;
		}
		if((op & 0xF08F) == 0x900A)
		{
			SLL(p1, p2);
			return;
		}
		if((op & 0xF01F) == 0x9008)
		{
			short disp16 = cast(short)(Fetch());
			uint erm = Seg(cast(ushort)(disp16 + GetERN(p2)));
			ubyte val = ReadByte(erm);
			LoadRegister(p1, val);
			return;
		}
		if((op & 0xF08F) == 0x900C)
		{
			SRL(p1, p2);
			return;
		}
		if((op & 0xF08F) == 0x900D)
		{
			SRLC(p1, p2);
			return;
		}
		
		if((op & 0xF08F) == 0x900E)
		{
			SRA(p1, p2);
			return;
		}
		if((op & 0xF01F) == 0x9009)
		{
			uint erm = Seg(cast(ushort)(Fetch() + GetERN(p2)));
			WriteByte(erm, REGS[p1]);
			return;
		}
		if((op & 0xF3FF) == 0x9054)
		{
			uint val = FetchDataInt(true);
			LoadXRn(p1, val);
			return;
		}
		if((op & 0xF3FF) == 0x9034)
		{
			uint val = FetchDataInt(false);
			LoadXRn(p1, val);
			return;
		}
		if((op & 0xF1FF) == 0x9033)
		{
			DropShort(GetERN(p1), false);
			return;
		}
		if((op & 0xF1FF) == 0x9053)
		{
			DropShort(GetERN(p1), true);
			return;
		}
		if((op & 0xF3FF) == 0x9035)
		{
			DropInt(GetXRN(p1), false);
			return;
		}
		if((op & 0xF1FF) == 0x9012)
		{
			uint addr = Seg(Fetch());
			LoadERn(p1, ReadWord(addr));
			return;
		}
		if((op & 0xF0FF) == 0x9030)
		{
			LoadRegister(p1, FetchDataByte(false));
			return;
		}
		if((op & 0xF0FF) == 0x9031)
		{
			DropByte(REGS[p1], false);
			return;
		}
		if((op & 0xF0FF) == 0x9051)
		{
			DropByte(REGS[p1], true);
			return;
		}
		if((op & 0xF7FF) == 0x9036)
		{
			FetchDataQR(p1, false);
			return;
		}
		if((op & 0xF7FF) == 0x9056)
		{
			FetchDataQR(p1, true);
			return;
		}
		if((op & 0xF7FF) == 0x9037)
		{
			DropQR(p1, false);
			return;
		}
		if((op & 0xF7FF) == 0x9057)
		{
			DropQR(p1, true);
			return;
		}
		if((op & 0xF1FF) == 0x9032)
		{
			LoadERn(p1, FetchDataWord(false));
			return;
		}
	}
	
	if(p0 == 0x0E)
	{
		if((op & 0xF180) == 0xE080) 
		{
			ushort imm7 = p23 & 0x7F;
			if((imm7 & 0x40) != 0) {
				imm7 |= (0xFFFF ^ 0x7F);
			}
			OP_Add16(p1, imm7);
			return;
		}
		if(op == 0xED08)
		{
			SetFlag(PSW_MIE,true);
			return;
		}
		if(op == 0xEBF7)
		{
			SetFlag(PSW_MIE,false);
			return;
		}
		if((op & 0xF180) == 0xE000)
		{
			ushort imm7 = p23 & 0x7F;
			if((imm7 & 0x40) != 0) {
				imm7 |= (0xFFFF ^ 0x7F);
			}
			Mov16(p1, imm7);
			return;
		}
		if((op & 0xFF00) == 0xE100)
		{
			SP += cast(byte)p23;
			return;
		}
		if(op == 0xEB7F)
		{
			SetFlag(PSW_C,false);
			return;
		}
		if(op == 0xED80)
		{
			SetFlag(PSW_C,true);
			return;
		}
		if((op & 0xFF00) == 0xE300)
		{
			DsrPrefix(p23);
			return;
		}
	}
	if(p0 == 0x0A)
	{
		if((op & 0xF08F) == 0xA001)
		{
			ubyte reg = REGS[p1];
			ubyte mask = 1 << (p2 & 7);
			SetFlag(PSW_Z, (reg & mask) == 0);
			return;
		}
		if((op & 0xF08F) == 0xA002)
		{
			ubyte reg = REGS[p1];
			ubyte mask = 1 << (p2 & 7);
			SetFlag(PSW_Z, (reg & mask) == 0);
			REGS[p1] = reg & (0xFF ^ mask);
			return;
		}
		if((op & 0xFF8F) == 0xA081)
		{
			uint addr = Seg(Fetch());
			ubyte reg = ReadByte(addr);
			ubyte mask = 1 << (p2 & 7);
			SetFlag(PSW_Z, (reg & mask) == 0);
			return;
		}
		if((op & 0xF1FF) == 0xA01A)
		{
			SetERn(p1, SP);
			return;
		}
		if((op & 0xFF1F) == 0xA10A)
		{
			SP = GetERN(p2);
			return;
		}
		if((op & 0xF11F) == 0xA008)
		{
			short disp16 = cast(short)Fetch();
			uint erm = Seg(cast(ushort)(disp16 + GetERN(p2)));
			LoadERn(p1, ReadWord(erm));
			return;
		}
		if((op & 0xF11F) == 0xA009)
		{
			short disp16 = cast(short)Fetch();
			uint erm = Seg(cast(ushort)(disp16 + GetERN(p2)));
			WriteWord(erm, GetERN(p1));
			return;
		}
		if((op & 0xF08F) == 0xA000)
		{
			ubyte reg = REGS[p1];
			ubyte mask = 1 << (p2 & 7);
			SetFlag(PSW_Z, (reg & mask) == 0);
			REGS[p1] = reg | mask;
			return;
		}
		if((op & 0xFF8F) == 0xA082)
		{
			uint addr = Seg(Fetch());
			ubyte reg = ReadByte(addr);
			ubyte mask = 1 << (p2 & 7);
			SetFlag(PSW_Z, (reg & mask) == 0);
			WriteByte(addr, reg & (0xFF ^ mask));
			return;
		}
		
	}
	
	if(p0 == 0x0B)
	{
		if((op & 0xF1C0) == 0xB040) {
			uint addr = Seg(cast(ushort)(cast(short)GetERN(14) + Disp6(p23)));
			LoadERn(p1, ReadWord(addr));
			return;
		}
		if((op & 0xF1C0) == 0xB0C0) {
			uint addr = Seg(cast(ushort)(cast(short)GetERN(14) + Disp6(p23)));
			WriteWord(addr, GetERN(p1));
			return;
		}
		if((op & 0xF1C0) == 0xB000) {
			uint addr = Seg(cast(ushort)(cast(short)GetERN(12) + Disp6(p23)));
			LoadERn(p1, ReadWord(addr));
			return;
		}
		if((op & 0xF1C0) == 0xB080) {
			uint addr = Seg(cast(ushort)(cast(short)GetERN(12) + Disp6(p23)));
			WriteWord(addr, GetERN(p1));
			return;
		}
	}
	
	if(p0 == 0x0D)
	{
		if((op & 0xF0C0) == 0xD000)
		{
			uint addr = Seg(cast(ushort)(cast(short)GetERN(12) + Disp6(p23)));
			LoadRegister(p1,ReadByte(addr));
			return;
		}
		if((op & 0xF0C0) == 0xD040)
		{
			uint addr = Seg(cast(ushort)(cast(short)GetERN(14) + Disp6(p23)));
			LoadRegister(p1,ReadByte(addr));
			return;
		}
		if((op & 0xF0C0) == 0xD080)
		{
			uint addr = Seg(cast(ushort)(cast(short)GetERN(12) + Disp6(p23)));
			WriteByte(addr,REGS[p1]);
			return;
		}
		if((op & 0xF0C0) == 0xD0C0)
		{
			uint addr = Seg(cast(ushort)(cast(short)GetERN(14) + Disp6(p23)));
			WriteByte(addr,REGS[p1]);
			return;
		}
	}
	writeln("@","%x:%x".format(CSR,PC-2),": %x".format(op));
	ULTRAHALT = true;
}

void Raise(ubyte indx)
{
	WriteWord(0xf014,ReadWord(0xf014) | cast(ushort)(1<<(indx-4)));
	HALT = false;
}

void Tick()
{
	if(ULTRAHALT)
	{
		return;
	}
	
	
	
	for(int i = 0; i < 256; i++)
	{
		if(HALT)
		{
			ushort counter = ReadWord(0xf022);
			if(counter >= ReadWord(0xf020))
			{
				counter -= ReadWord(0xf020);
				Raise(9);
			}
			WriteWord(cast(uint)0xf022,cast(ushort)(counter+1));
		}
		else
		{
			for(int j = 0; j < 256; j++)
			{
				if(HALT)
				{
					break;
				}
				Execute(Fetch());
			
				if(FLAG_DSR)
				{
					ADSR = DSR;
					FLAG_DSR = false;
				}
				else
				{
					ADSR = 0;
				}
			}
		}
		
		
		
		
		
	}
	
}

void Init()
{
	auto romfile = File("rom.bin","rb");
	romfile.rawRead(rom);
	romfile.close();
	PC = ReadCode(2);
	CSR = 0;
	SP = ReadCode(0);
}