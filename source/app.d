import std.file;
import std.path;
import std.stdio;
import std.string;
import bindbc.glfw;
import dgui;
import bindbc.opengl.util;
import emu;
import hexedit;
import std.format;
import fuzz;

extern(C) @nogc nothrow void errorCallback(int error, const(char)* description) {
	import core.stdc.stdio;
	fprintf(stderr, "Error: %s\n", description);
}

bool mouse_pending = false;
bool mouse_scroll_pending = false;
int mouse_button = 0;
int mouse_action = 0;
int mouse_x = 0;
int mouse_y = 0;
double mouse_scroll = 0;
version(SOLARII)
{
	string currom = "solarii_emu.bin";
}
else version(CWII)
{
	string currom = "cwii.bin";
}
else version(ES)
{
	string currom = "rom018_emu.bin";
}
else version(CWX)
{
	string currom = "cwx.bin";
}

extern(C) @nogc nothrow void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
{
	double dxpos, dypos;
	glfwGetCursorPos(window, &dxpos, &dypos);
	mouse_x = cast(int)dxpos;
	mouse_y = cast(int)dypos;
	mouse_scroll = yoffset;
	mouse_scroll_pending = true;
}

extern(C) @nogc nothrow void mouse_button_callback(GLFWwindow* window, int button, int action, int mods)
{
	double dxpos, dypos;
	glfwGetCursorPos(window, &dxpos, &dypos);
	mouse_x = cast(int)dxpos;
	mouse_y = cast(int)dypos;
	mouse_button = button;
	mouse_action = action;
	mouse_pending = true;
}



bool key_pending = false;
uint key_chr = 0;

extern(C) @nogc nothrow void text_callback(GLFWwindow* window, uint chr)
{
	key_pending = true;
	key_chr = chr;
}

extern(C) @nogc nothrow void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (key >= 256 && action == GLFW_PRESS)
	{
		key_pending = true;
        key_chr = -key;
	}
}

bool GetBit(int bitn)
{
	return (emu.display[bitn>>3]&(1<<(7^(bitn&0x7)))) != 0;
}

void checkShaderError(GLuint shader, string type)
{
	GLint success;
	glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
	if(!success)
	{
		GLint logLen;
		glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLen);
		char[] log = new char[logLen];
		glGetShaderInfoLog(shader, logLen, null, log.ptr);
		writeln(type, " Shader Error:\n", log);
	}
}

void checkProgramError(GLuint program)
{
    GLint success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if(!success)
	{
        GLint logLen;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);
        char[] log = new char[logLen];
        glGetProgramInfoLog(program, logLen, null, log.ptr);
		writeln("Program Linking Error:\n", log);
    }
}


GLuint compileProgram(string vertexSource, string fragmentSource)
{
	GLuint vShader = glCreateShader(GL_VERTEX_SHADER);
	auto vSourcePtr = vertexSource.toStringz;
	glShaderSource(vShader, 1, &vSourcePtr, null);
	glCompileShader(vShader);
	checkShaderError(vShader, "Vertex");

	GLuint fShader = glCreateShader(GL_FRAGMENT_SHADER);
	auto fSourcePtr = fragmentSource.toStringz;
	glShaderSource(fShader, 1, &fSourcePtr, null);
	glCompileShader(fShader);
	checkShaderError(fShader, "Fragment");

	GLuint program = glCreateProgram();
	glAttachShader(program, vShader);
	glAttachShader(program, fShader);
	glLinkProgram(program);
	checkProgramError(program);

	glDeleteShader(vShader);
	glDeleteShader(fShader);

	return program;
}

class Display : Panel
{
	GLuint planes;
	GLuint program;
	GLuint vbo, vao;
	GLint modelLoc;
	float[16] vertices = [0,0,1,0,1,1,0,1];
	this(Panel parent)
	{
		super(parent);
		
		
		
		width = 194;
		height = 66;
		glGenTextures(1,&planes);
		glBindTexture(GL_TEXTURE_2D, planes);
		writeln(__LINE__,":",glGetError());
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);	
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		writeln(__LINE__,":",glGetError());
		glTexImage2D(GL_TEXTURE_2D, 0, GL_R8UI, 32, 128, 0, GL_RED_INTEGER, GL_UNSIGNED_BYTE, emu.display.ptr);
		writeln(__LINE__,":",glGetError());
		glBindTexture(GL_TEXTURE_2D, 0);
		writeln(__LINE__,":",glGetError());
		program = compileProgram(import("Vert.glsl"),import("Frag.glsl"));
		GLint planesLoc = glGetUniformLocation(program, "planes");
		glUseProgram(program);
		glUniform1i(planesLoc, 0); // Texture unit 0 is for base images.
		glUseProgram(0);
		modelLoc = glGetUniformLocation(program, "model_matrix");
		glGenBuffers(1, &vbo);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, vertices.length, vertices.ptr, GL_STATIC_DRAW);
		
		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);
		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
		glBindVertexArray(0);

	}
	
	override void DrawBackground()
	{
		glBlendColor4ub(255,255,255,255);
		//DGUI_FillRect(0,0,194,66);
		glTranslatef(1,2,0);
		ubyte* dp = emu.display.ptr;
		version(CWII)
		{
			glUseProgram(program);
			
			int s_width, s_height;
		
			glfwGetFramebufferSize(window, &s_width, &s_height);
		
		
			glBindTexture(GL_TEXTURE_2D, planes);
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 32, 128, GL_RED_INTEGER, GL_UNSIGNED_BYTE, emu.display.ptr);
			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, planes);
			glBindVertexArray(vao);
			//glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
			//writeln(glGetError());
			DGUI_FillRect(0,0,192,64);
			glUseProgram(0);
			/*
			glBlendColor4ub(254,78,3,255);
			glRasterPos2i(0,0);
			for(int i = 0; i < 64; i++)
			{
				glBitmap(192,1,0,0,0,-1.0,(cast(GLubyte*)dp+i*32));
			}
			glBlendEquationSeparate(GL_FUNC_SUBTRACT,GL_FUNC_ADD);
			glBlendFuncSeparate(GL_ONE,GL_ONE,GL_ONE,GL_ONE);
			glBlendColor4ub(255-103,255-0,255-51,255);
			glRasterPos2i(0,0);
			dp = emu.display.ptr + 0x800;
			for(int i = 0; i < 64; i++)
			{
				glBitmap(192,1,0,0,0,-1.0,(cast(GLubyte*)dp+i*32));
			}
			glBlendEquation(GL_FUNC_ADD);
			glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA,GL_ONE,GL_ONE);
			*/
		}
		version(CWX)
		{
			glBlendColor4ub(0,0,0,255);
			glRasterPos2i(0,0);
			for(int i = 0; i < 64; i++)
			{
				glBitmap(192,1,0,0,0,-1.0,(cast(GLubyte*)dp+i*32));
			}
		}
		version(ES)
		{
			glBlendColor4ub(0,0,0,255);
			glRasterPos2i(0,0);
			for(int i = 0; i < 32; i++)
			{
				glBitmap(96,1,0,0,0,-1.0,(cast(GLubyte*)dp+i*16));
			}
		}
		version(SOLARII)
		{
			glBlendColor4ub(0,0,0,255);
			
			for(int i = 0; i < 13; ++i)
			{
				int idx = ((i + 1) << 2) | 1;
				int x = i*16;
				int sub = 6;
				if(i == 11)
				{
					glScalef(0.5,0.5,1);
					glTranslatef(x+4,0,0);
				}
				bool a = GetBit(idx);
				bool b = GetBit(idx + 0x1);
				bool c = GetBit(idx + 0x2);
				bool d = GetBit(idx + 0x40);
				bool e = GetBit(idx + 0x41);
				bool f = GetBit(idx + 0x42);
				bool g = GetBit(idx + 0x81);
				bool point = GetBit(idx + 0x82);
				bool flag = GetBit(idx + 0x80);
				if(a)
				{
					DGUI_FillRect(x,0,2,12);
				}
				if(b)
				{
					DGUI_FillRect(x,0,12,2);
				}
				if(c)
				{
					DGUI_FillRect(sub*2+x-2,0,2,12);
				}
				if(d)
				{
					DGUI_FillRect(x,sub*2-2,2,12);
				}
				if(e)
				{
					DGUI_FillRect(x,sub*2-2,12,2);
				}
				if(f)
				{
					DGUI_FillRect(sub*2+x-2,sub*2,2,12);
				}
				if(g)
				{
					DGUI_FillRect(x,sub*4-2,12,2);
				}
				if(point)
				{
					if(i == 12)
					{
						DGUI_DrawText(x-sub*3,sub*4+32,"SD");
					}
					else
					{
						DGUI_FillRect(x+sub*2+1,sub*4-3,2,6);
					}
				}
				if(flag)
				{
					if(i == 11)
					{
						DGUI_FillRect(x-sub-4,sub*2-2,8,2);
					}
					else
					{
						DGUI_DrawText(x,sub*4+16,digitflags[i]);
					}
				}
				
			}
			glTranslatef(-11*16,0,0);
			glScalef(2,2,1);
			
		}
		glTranslatef(-1,-2,0);
	}
}

version(CWII)
{
	const string[64] labels = [
	"     ","SETUP","SHIFT","  x  ", " (-) ", "  7  ","  4  ","  1  ",
	"MODE ","BACK "," VAR ","frac "," sin ","  8  ","  5  ","  2  ",
	"     ", "LEFT ","f(x) ","sqrt "," cos ","  9  ","  6  ","  3  ",
	"  UP ","  OK ","DOWN "," x^( "," tan "," DEL ", "  *  ", "  +  ",
	"     ","RIGHT","CATLG"," x^2 ","  (  "," AC  ","  /  ", "  -  ",
	" /\\  "," \\/  ","TOOLS","log_n","  )  ","     ","     ","     ",
	"     ","     ","     ","  0  ","  .  ","*10^x","FORM.","  =  ",
	"     ","     ","     ","     ","     ","     ","     ","     "];
} 
else version(SOLARII)
{
	const string[64] labels = [
	"     ","     ","SHIFT","a b/c"," +/- ","  7  ","  4  ","  1  ",
	"     ","     ","MODE ","*' ''","  >  ","  8  ","  5  ","  2  ",
	"     ","     "," x^2 "," hyp ","((---","  9  ","  6  ","  3  ",
	"     ","     "," log "," sin ","---))","  C  ","  *  ","  +  ",
	"     ","     ","  ln "," cos "," x^y ","  AC ","  /  ","  -  ",
	"     ","     ","     "," tan ","  MR ","     ","     ","     ",
	"     ","     ","     ","  0  ","  .  "," EXP ","  =  ","  M+ ",
	"     ","     ","     ","     ","     ","     ","     ","     "
	];
	
} 
else version(ES)
{
	const string[64] labels = [
	"SHIFT"," CALC"," frac"," (-) "," RCL ","  7   ","  4   ","  1   ",
	"ALPHA","INTEG"," sqrt"," dms "," ENG ","  8   ","  5   ","  2   ",
	"^"," <"," x^2 "," hyp ","  (  ","  9   ","  6   ","  3   ",
	"> ","v"," x^( "," sin ","  )  "," DEL  ","  *   ","  +   ",
	" MODE"," x^-1"," log "," cos "," S<>D","  AC  ","  /   ","  -   ",
	"     ","log_n","  ln "," tan ","  M+ ","     ","     ","     ",
	"     ","     ","     ","  0   ","  .   ","*10^x "," Ans  ","  =   ",
	"     ","     ","     ","     ","     ","     ","     ","     "
	];
}
else version(CWX)
{
	const string[64] labels = [
	"SHIFT"," CALC"," frac"," (-) "," RCL ","  7   ","  4   ","  1   ",
	"ALPHA","INTEG"," sqrt"," dms "," ENG ","  8   ","  5   ","  2   ",
	"^"," <"," x^2 "," hyp ","  (  ","  9   ","  6   ","  3   ",
	"> ","v"," x^( "," sin ","  )  "," DEL  ","  *   ","  +   ",
	" MODE"," x^-1"," log "," cos "," S<>D","  AC  ","  /   ","  -   ",
	"     ","log_n","  ln "," tan ","  M+ ","     ","     ","     ",
	"     ","     ","     ","  0   ","  .   ","*10^x "," Ans  ","  =   ",
	"     ","     ","     ","     ","     ","     ","     ","     "
	];
}
const string[13] digitflags = ["0","S","M","3","4","5","M","K","DEG","RAD","GRA","11","12"];




class MainApp : Panel
{
	HexEdit hed;
	Button fuck;
	Button fuz;
	this(Panel parent)
	{
		super(parent);
		content = new Panel(this);
		screen = new Display(content);
		version(FUZZ)
		{
		
		}
		else
		{
			hed = new HexEdit(content);
			hed.x = 720;
			hed.y = 8;
			ON = new Button(content,"ON");
			ON.callback = &PressON;
			ON.x = 256;
			ON.y = 4;
			/*
			fuck = new Button(content,"Fuck");
			fuck.callback = &PressFuck;
			fuck.x = 256;
			fuck.y = 38;
			fuz = new Button(content,"Fuzz");
			fuz.callback = &PressFuzz;
			fuz.x = 256;
			fuz.y = 38+16;
			ANB = new Button(content,"an");
			ANB.callback = &AnButton;
			ANB.x = 256;
			ANB.y = 20;
			*/
			version(ES)
			{
				for(int i = 2; i <= 4; i++)
				{
					for(int j = 0; j <= 5; j++)
					{
						Button newb = new Button(content);
						newb.x = j * 44 + 5;
						newb.y = i * 18 + 72;
						newb.callback3 = &PressButton;
						newb.callback2 = &ReleaseButton;
						newb.text = labels[j*8+i];
						newb.userdata = j*8+i;
						buttons ~= newb;
					}
				}
				for(int i = 5; i <= 7; i++)
				{
					for(int j = 0; j <= 4; j++)
					{
						Button newb = new Button(content);
						newb.x = j * 53 + 5;
						newb.y = i * 18 + 72;
						newb.callback3 = &PressButton;
						newb.callback2 = &ReleaseButton;
						newb.text = labels[j*8+i];
						newb.userdata = j*8+i;
						buttons ~= newb;
					}
				}
				for(int i = 3; i <= 7; i++)
				{
					Button newb = new Button(content);
					newb.x = (i-3) * 53 + 5;
					newb.y = (8) * 18 + 72;
					newb.callback3 = &PressButton;
					newb.callback2 = &ReleaseButton;
					newb.text = labels[6*8+i];
					newb.userdata = 6*8+i;
					buttons ~= newb;
				}
				for(int i = 0; i <= 1; i++)
				{
					for(int j = 0; j <= 5; j++)
					{
						if(j == 5 && i == 0)
						{
							break;
						}
						Button newb = new Button(content);
						
						if(j == 2 || j == 3)
						{
							newb.x = ((j*2-5)-i*2)*8 + 3*44 + 5 - ((j-2+i)&1)*4;
							newb.y = ((i*2-1)+j*2-6)*4  + 1*18 + 66;
						}
						else
						{
							newb.x = j * 44 + 5;
							newb.y = i * 18 + 72;
						}
						
						newb.callback3 = &PressButton;
						newb.callback2 = &ReleaseButton;
						newb.text = labels[j*8+i];
						newb.userdata = j*8+i;
						buttons ~= newb;
					}
				}
			}
			else
			{
				for(int i = 0; i < 8; i++)
				{
					for(int j = 0; j < 8; j++)
					{
						Button newb = new Button(content);
						newb.x = j * 44 + 5;
						newb.y = i * 18 + 72;
						newb.callback3 = &PressButton;
						newb.callback2 = &ReleaseButton;
						newb.text = labels[j*8+i];
						newb.userdata = j*8+i;
						buttons ~= newb;
					}
				}
			}
			foreach(string potentialrom; dirEntries(".",SpanMode.shallow))
			{
				if(extension(potentialrom) == ".bin")
				{
					Button rombutton = new Button(content);
					rombutton.x = 540;
					rombutton.y = cast(int)(roms.length)*20;
					rombutton.text = potentialrom;
					rombutton.callback3 = &LoadRom;
					roms ~= rombutton;
				}
			}
			SaveButton = new Button(content,"Save");
			SaveButton.x = 300;
			SaveButton.y = 4;
			SaveButton.callback = &Save;
			LoadButton = new Button(content,"Load");
			LoadButton.x = 460;
			LoadButton.y = 4;
			LoadButton.callback = &Load;
			SaveName = new Textbox(content);
			SaveName.x = 332;
			SaveName.y = 4;
			SaveName.width = 128;
			SaveName.text = "default";
		}
		
	}
	
	void PressFuzz()
	{
		ExecuteRandomPayload();
	}
	
	void LoadRom(Button b)
	{
		currom = b.text;
		emu.Init(currom);
		emu.Reset();
	}
	
	void Save()
	{
		auto sav = File(SaveName.text ~ ".sav","wb");
		sav.rawWrite([emu.PC]);
		sav.rawWrite([emu.SP]);
		sav.rawWrite([emu.PSW]);
		sav.rawWrite([emu.EA]);
		sav.rawWrite([emu.DSR]);
		sav.rawWrite([emu.FLAG_DSR]);
		sav.rawWrite([emu.ADSR]);
		sav.rawWrite(emu.REGS);
		sav.rawWrite(data);
		sav.rawWrite(display);
		sav.rawWrite([emu.CSR]);
		sav.close();
	}
	
	void LoadSav(string savname)
	{
		auto sav = File(savname,"rb");
		emu.PC = sav.rawRead([emu.PC])[0];
		emu.SP = sav.rawRead([emu.SP])[0];
		emu.PSW = sav.rawRead([emu.PSW])[0];
		emu.EA = sav.rawRead([emu.EA])[0];
		emu.DSR = sav.rawRead([emu.DSR])[0];
		emu.FLAG_DSR = sav.rawRead([emu.FLAG_DSR])[0];
		emu.ADSR = sav.rawRead([emu.ADSR])[0];
		sav.rawRead(emu.REGS);
		sav.rawRead(data);
		sav.rawRead(display);
		emu.CSR = sav.rawRead([emu.CSR])[0];
		sav.close();
		emu.ULTRAHALT = false;
		emu.HALT = false;
	}
	
	void Load()
	{
		LoadSav(SaveName.text ~ ".sav");
	}
	
	void PressON()
	{
		version(TESTGLITCH)
		{
			emu.buttons[0] = 128;
			emu.Raise(5);
			for(int i = 718; i >= 0; --i)
			{
				emu.Tick();
			}
			writeln("RESET");
			emu.Reset();
			emu.ULTRAHALT = true;
		}
		else
		{
			emu.ULTRAHALT = false;
			emu.HALT = false;
			//emu.Init(currom);
			emu.Reset();
		}
	}
	
	void PressFuck()
	{
		int i = 25;
		emu.buttons[i>>3] |= 1<<(7-(i&0x7));
		writeln("BUTTON: ",i>>3," ",7-(i&0x7));
		
		emu.Raise(5);
		foreach(_c; 0..6000)
		{
			if(emu.HALT)
			{
				ushort counter = ReadWord(0xf022);
				writeln("L",__LINE__, ": ", counter, " - ", ReadWord(0xf020));
				if(counter >= ReadWord(0xf020))
				{
					counter -= ReadWord(0xf020);
					Raise(9);
				}
				else
				{
					WriteWord(cast(uint)0xf022,ReadWord(0xf020));
					counter = 0;
					Raise(9);
				}
				WriteWord(cast(uint)0xf022,cast(ushort)(counter+1));
			}
			else
			{
				emu.Tick();
			}
		}
		
		emu.buttons[i>>3] &= ~(1<<(7-(i&0x7)));
		emu.Raise(5);
		
		foreach(_c; 0..4000)
		{
			if(emu.HALT)
			{
				ushort counter = ReadWord(0xf022);
				writeln("L",__LINE__, ": ", counter, " - ", ReadWord(0xf020));
				if(counter >= ReadWord(0xf020))
				{
					counter -= ReadWord(0xf020);
					Raise(9);
				}
				else
				{
					WriteWord(cast(uint)0xf022,ReadWord(0xf020));
					counter = 0;
					Raise(9);
				}
				WriteWord(cast(uint)0xf022,cast(ushort)(counter+1));
			}
			else
			{
				emu.Tick();
			}
		}
		
		PressON();
	}
	
	void AnButton()
	{
		emu.WriteWord(0x9268,0x20fd);
	}
	
	void PressButton(Button b)
	{
		int i = b.userdata;
		emu.buttons[i>>3] |= 1<<(7-(i&0x7));
		writeln("BUTTON: ",i>>3," ",7-(i&0x7));
		
		emu.Raise(5);
	}
	
	void ReleaseButton(Button b)
	{
		int i = b.userdata;
		emu.buttons[i>>3] &= ~(1<<(7-(i&0x7)));
		
		//emu.Raise(5);
	}
	
	override void PerformLayout()
	{
		content.width = width-8;
		content.height = height-8;
		content.x = 4;
		content.y = 4;
		screen.x = 4;
		screen.y = 4;
		hed.width = content.width - hed.x;
		hed.height = content.height - hed.y;
	}
	
	void SetContent(Panel newcontent)
	{
		content.hidden = true;
		newcontent.hidden = false;
		content = newcontent;
	}
	
	
	Panel content;
	Display screen;
	Button[] buttons;
	Button ON;
	Button ANB;
	Button[] roms;
	Button SaveButton;
	Button LoadButton;
	Textbox SaveName;
	
}

MainApp app;



void main(string[] args)
{
	version(Windows)
	{
		loadGLFW();
	}
	if(args.length > 1)
	{
		currom = args[1];
	}
	glfwSetErrorCallback(&errorCallback);
	glfwInit();
	
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
	
	glfwWindowHint(GLFW_TRANSPARENT_FRAMEBUFFER, 1);
	glfwWindowHint(GLFW_DECORATED, 0);
	window = glfwCreateWindow(1280, 720, "CasioEmuD", null, null);
	glfwSetMouseButtonCallback(window, &mouse_button_callback);
	glfwSetCharCallback(window, &text_callback);
	glfwSetKeyCallback(window, &key_callback);
	glfwSetScrollCallback(window, &scroll_callback);
	
	glfwMakeContextCurrent(window);
	
	glfwSwapInterval(1);
	loadOpenGL();
	loadExtendedGLSymbol(cast(void**)&glBitmap, "glBitmap");
	if(glBitmap == null)
	{
		loadBaseGLSymbol(cast(void**)&glBitmap, "glBitmap");
	}
	if(glBitmap == null)
	{
		writeln("couldnt find glBitmap in your system.");
	}
	mainpanel = new Window();
	
	app = new MainApp(mainpanel);
	
	mainpanel.inner.destroy();
	mainpanel.inner = app;
	
	ushort twobyte = 0xffff;
	
	emu.Init(currom);
	while (!glfwWindowShouldClose(window))
	{
		glfwPollEvents();
		
		if(mouse_pending)
		{
			DGUI_HandleMouse(mouse_x,mouse_y,mouse_button,mouse_action);
			mouse_pending = false;
		}
		
		if(mouse_scroll_pending)
		{
			DGUI_HandleScroll(mouse_x,mouse_y,mouse_scroll);
			mouse_scroll_pending = false;
		}
		
		if(key_pending)
		{
			DGUI_HandleKey(key_chr);
			key_pending = false;
		}
		
		version(FUZZ)
		{
			foreach(i;0..100)
			{
				emu.Fuzz();
			}
		}
		else version(ANFIND)
		{
			app.LoadSav("anfind.sav");
			emu.WriteByte(0x9268,twobyte>>8);
			emu.WriteByte(0x9269,twobyte&0xff);
			emu.WriteWord(0x926a,0x6767);
			emu.WriteWord(0x926c,0x6767);
			emu.WriteWord(0x926e,0x6767);
			emu.WriteInt(0x9270,0x67676767);
			emu.WriteInt(0x9274,0x67676767);
			emu.WriteInt(0x9278,0x67676767);
			emu.WriteInt(0x927c,0x67676767);
			emu.buttons[6] |= 1;
			emu.Raise(5);
			emu.HALT = false;
			emu.ULTRAHALT = false;
			foreach(i;0..500960)
			{
				emu.Tick();
				if(emu.SP == 0x6767)
				{
					writeln(twobyte);
					break;
				}
				if(emu.ULTRAHALT)
				{
					break;
				}
				if(emu.CSR == 3 && emu.PC == 0xeee2)
				{
					break;
				}
				emu.HALT = false;
			}
			twobyte -= 1;
		}
		else version(TESTGLITCH)
		{
			for(int i = 0; i < 64; i++)
			{
				emu.Tick();
			}
		}
		else
		{
			emu.RunFrame();
		}
		
		int width, height;
		
		glEnable(GL_BLEND);
		glfwGetFramebufferSize(window, &width, &height);
		glViewport(0, 0, width, height);
		glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
		glClear(GL_COLOR_BUFFER_BIT);
		glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA,GL_ONE,GL_ONE);
		
		DGUI_Draw(width,height);
		
		glfwSwapBuffers(window);
		
	}
	glfwTerminate();
}
