import emu;
import app;
import std.string;
import std.format;
import std.stdio;
import std.random;

struct Step
{
	int button;
	
	string opCast(T)()
	{
		return labels[button];
	}
	
	void DoStep()
	{
		*(cast(ulong*)(emu.buttons.ptr)) = 0; // release all buttons
		emu.buttons[button>>3] |= 1<<(7-(button&0x7));
		emu.Raise(5);
	}

}

struct Payload
{
	Step[] steps;
	bool[ushort] coverage;
	
	void Execute()
	{
		foreach(step; steps)
		{
			step.DoStep();
			while(!emu.HALT)
			{
				emu.Tick();
				coverage[cast(ushort)emu.PC] = true;
			}
		}
	}
}


void ExecuteRandomPayload()
{
	Payload p;
	foreach(i; 0..8)
	{
		p.steps ~= Step(uniform(0,64,rndGen()));
	}
	writeln(p.steps);
	p.Execute();
	*(cast(ulong*)(emu.buttons.ptr)) = 0; // release all buttons
}