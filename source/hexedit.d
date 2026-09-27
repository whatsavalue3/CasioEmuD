import dgui;
import emu;
import std.string;
import std.format;
import std.stdio;

class HexEdit : Panel
{
	uint scroll = 0x9200;
	this(Panel parent)
	{
		super(parent);
	}
	
	override void DrawBackground()
	{
		
		foreach(spot, ref bright; emu.SPSPOTS)
		{
			if(bright == Spot(0))
			{
				emu.SPSPOTS.remove(spot);
				continue;
			}
			glBlendColor4ub(--bright[0],--bright[1],--bright[2],255);
			uint relativespot = spot-scroll;
			int x = relativespot&0xf;
			int y = relativespot>>4;
			DGUI_FillRect(48+x*18,y*18,16,16);
		}
		
		glBlendColor4ub(255,255,255,255);
		glBegin(GL_LINES);
		glVertex2i(0,17);
		glVertex2i(width,17);
		glVertex2i(48,17);
		glVertex2i(48,height);
		glEnd();
		
		
		
		foreach(x; 0..16)
		{
			DGUI_DrawText(48+x*18,16,"%02x".format(x));
		}
		
		foreach(y; 1..height/18)
		{
			DGUI_DrawText(0,y*18+16,"%04x".format(scroll+y*16));
			foreach(x; 0..16)
			{
				string val = "%02x".format(emu.ReadByte(x+y*16+scroll,false));
				glBlendColor4ub(0,0,0,255);
				DGUI_DrawText(49+x*18,y*18+17,val);
				glBlendColor4ub(255,255,255,255);
				DGUI_DrawText(48+x*18,y*18+16,val);
				
			}
		}
		
		
		foreach(y; 0..16)
		{
			DGUI_DrawText(48+18*18+2,50+16+16+y*16,"R%d=%02x".format(y,emu.REGS[y]));
		}
		DGUI_DrawText(48+18*18,50,"PC=%x:%04x".format(emu.CSR,emu.PC));
		DGUI_DrawText(48+18*18,50+16,"SP=%04x  LR=%x:%04x".format(emu.SP,emu.ECSR[emu.PSW&3],emu.ELR[emu.PSW&3]));
		
		int x;
		int y;
		int relativespot;
		
		relativespot = emu.SP - scroll;
		x = relativespot&0xf;
		y = relativespot>>4;
		
		
		
		glBegin(GL_LINES);
		glVertex2i(48+18*18,50+16);
		glVertex2i(48+x*18,y*18);
		glEnd();
		DGUI_PutRect(48+x*18,y*18,16,16);
	}
	
	override void Click(int cx, int cy, int button, int action)
	{
		writeln(cx," ",cy," ",button," ",action);
		bool big = ((cx-48)/9)%2 == 0;
		
		uint addr = cast(uint)(((cx-48)/18)%16 + ((cy/18)<<4))+scroll;
		if(action == 1)
		{
			if(button == 0)
			{
				emu.WriteByte(addr,cast(ubyte)(emu.ReadByte(addr,false)+(big ? 16 : 1)));
			}
			else if(button == 1)
			{
				emu.WriteByte(addr,cast(ubyte)(emu.ReadByte(addr,false)-(big ? 16 : 1)));
			}
		}
		
	}
	
	override void Scroll(int cx, int cy, double sv)
	{
		scroll = scroll-cast(int)(sv)*256;
	}
}