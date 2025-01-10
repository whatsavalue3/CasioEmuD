import std.file;
import std.path;
import std.stdio;
import glfw3.api;
import dgui;
import bindbc.opengl.util;
import emu;


extern(C) @nogc nothrow void errorCallback(int error, const(char)* description) {
	import core.stdc.stdio;
	fprintf(stderr, "Error: %s\n", description);
}

bool mouse_pending = false;
int mouse_button = 0;
int mouse_action = 0;
int mouse_x = 0;
int mouse_y = 0;
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

const float[] pixelmaprgb = [0.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0];
const float[] pixelmapa = [1.0,1.0];

class Display : Panel
{
	this(Panel parent)
	{
		super(parent);
		width = 194;
		height = 66;
	}
	
	override void DrawBackground()
	{
		glBlendColor4ub(224,224,224,255);
		DGUI_FillRect(0,0,194,66);
		glTranslatef(1,1,0);
		ubyte* dp = emu.display.ptr;
		version(CWII)
		{
			glBlendColor4ub(0,0,0,64);
			glPixelStorei(GL_UNPACK_ALIGNMENT,1);
			for(int i = 0; i < 64; i++)
			{
				//glRasterPos2i(0,i);
				glRasterPos2i(0,0);
				glBitmap(192,1,0,0,0,0,(cast(GLubyte*)dp+i*32));
				glTranslatef(0,1,0);
			}
			glTranslatef(0,-64,0);
			glBlendColor4ub(0,0,0,128);
			dp = emu.display.ptr + 0x800;
			for(int i = 0; i < 64; i++)
			{
				glRasterPos2i(0,0);
				glBitmap(192,1,0,0,0,0,(cast(GLubyte*)dp+i*32));
				glTranslatef(0,1,0);
			}
			glPixelStorei(GL_UNPACK_ALIGNMENT,4);
			glTranslatef(0,-64,0);
		}
		version(ES)
		{
			glBlendColor4ub(0,0,0,255);
			glPixelStorei(GL_UNPACK_ALIGNMENT,1);
			for(int i = 0; i < 32; i++)
			{
				glRasterPos2i(0,0);
				glBitmap(96,1,0,0,0,0,(cast(GLubyte*)dp+i*16));
				glTranslatef(0,1,0);
			}
			glPixelStorei(GL_UNPACK_ALIGNMENT,4);
			glTranslatef(0,-32,0);
		
		/*
			glBlendColor4ub(255,255,255,255);
			glRasterPos2i(0,32);
			glPixelMapfv(GL_PIXEL_MAP_I_TO_R,0x2,pixelmaprgb.ptr);
			glPixelMapfv(GL_PIXEL_MAP_I_TO_G,0x2,pixelmaprgb.ptr);
			glPixelMapfv(GL_PIXEL_MAP_I_TO_B,0x2,pixelmaprgb.ptr);
			glPixelMapfv(GL_PIXEL_MAP_I_TO_A,0x2,pixelmapa.ptr);
			//glPixelTransferi(GL_MAP_COLOR,0);
			//glPixelTransferf(GL_RED_SCALE,255.0);
			glPixelTransferi(GL_INDEX_SHIFT,0);
			glPixelTransferi(GL_INDEX_OFFSET,0);
			glPixelStorei(GL_UNPACK_ALIGNMENT,1);
			//for(int i = 0; i < 32; i++)
			//{
				//glRasterPos2i(0,i);
				//glPixelZoom(2.0,2.0);
			//*(dp+0x140) = 0xff;
			writeln(dp[32]);
			glDrawPixels(128,32,GL_COLOR_INDEX,GL_BITMAP,dp);
			glPixelStorei(GL_UNPACK_ALIGNMENT,4);
				//glBitmap(96,1,0,0,0,0,(cast(GLubyte*)dp+i*16));
				
			//}
			*/
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
			//glRasterPos2i(0,4);
			//glBitmap(64,4,0,0,0,0,(cast(GLubyte*)dp));
			
		}
		glTranslatef(-1,-1,0);
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
version(SOLARII)
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
version(ES)
{
	const string[64] labels = [
	"SHIFT"," CALC"," frac"," (-) "," RCL ","  7  ","  4  ","  1  ",
	"ALPHA","INTEG"," sqrt"," dms "," ENG ","  8  ","  5  ","  2  ",
	"  UP "," LEFT"," x^2 "," hyp ","  (  ","  9  ","  6  ","  3  ",
	"RIGHT"," DOWN"," x^( "," sin ","  )  "," DEL ","  *  ","  +  ",
	" MODE"," x^-1"," log "," cos "," S<>D","  AC ","  /  ","  -  ",
	"     ","log_n","  ln "," tan ","  M+ ","     ","     ","     ",
	"     ","     ","     ","  0  ","  .  ","*10^x"," Ans ","  =  ",
	"     ","     ","     ","     ","     ","     ","     ","     "
	];
}



const string[13] digitflags = ["0","S","M","3","4","5","M","K","DEG","RAD","GRA","11","12"];

class MainApp : Panel
{
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
			ON = new Button(content,"ON");
			ON.callback = &PressON;
			for(int i = 0; i < 8; i++)
			{
				for(int j = 0; j < 8; j++)
				{
					Button newb = new Button(content);
					newb.x = i * 44 + 5;
					newb.y = j * 18 + 72;
					newb.callback3 = &PressButton;
					newb.callback2 = &ReleaseButton;
					newb.text = labels[buttons.length];
					buttons ~= newb;
				}
			}
			foreach(string potentialrom; dirEntries(".",SpanMode.shallow))
			{
				if(extension(potentialrom) == ".bin")
				{
					Button rombutton = new Button(content);
					rombutton.x = 480;
					rombutton.y = cast(int)(roms.length)*20;
					rombutton.text = potentialrom;
					rombutton.callback3 = &LoadRom;
					roms ~= rombutton;
				}
			}
		}
		
	}
	
	void LoadRom(Button b)
	{
		currom = b.text;
		emu.Init(currom);
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
	
	void PressButton(Button b)
	{
		int i = 0;
		foreach(Button check; buttons)
		{
			if(check == b)
			{
				emu.buttons[i>>3] |= 1<<(7-(i&0x7));
				writeln("BUTTON: ",i>>3," ",7-(i&0x7));
				break;
			}
			i++;
		}
		
		emu.Raise(5);
	}
	
	void ReleaseButton(Button b)
	{
		int i = 0;
		foreach(Button check; buttons)
		{
			if(check == b)
			{
				emu.buttons[i>>3] &= ~(1<<(7-(i&0x7)));
				break;
			}
			i++;
		}
		
		emu.Raise(5);
	}
	
	override void PerformLayout()
	{
		content.width = width-8;
		content.height = height-8;
		content.x = 4;
		content.y = 4;
		screen.x = 4;
		screen.y = 4;
		version(FUZZ)
		{
		
		}
		else
		{
			ON.x = 256;
			ON.y = 4;
		}
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
	Button[] roms;
}

MainApp app;



void main()
{
	glfwSetErrorCallback(&errorCallback);
	glfwInit();
	
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
	
	glfwWindowHint(GLFW_TRANSPARENT_FRAMEBUFFER, 1);
	glfwWindowHint(GLFW_DECORATED, 0);
	window = glfwCreateWindow(1280, 720, "CasioEmuD", null, null);
	glfwSetMouseButtonCallback(window, &mouse_button_callback);
	glfwSetCharCallback(window, &text_callback);
	glfwSetKeyCallback(window, &key_callback);
	
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
	
	
	
	emu.Init(currom);
	while (!glfwWindowShouldClose(window))
	{
		glfwPollEvents();
		
		if(mouse_pending)
		{
			DGUI_HandleMouse(mouse_x,mouse_y,mouse_button,mouse_action);
			mouse_pending = false;
		}
		
		if(key_pending)
		{
			DGUI_HandleKey(key_chr);
			key_pending = false;
		}
		
		version(FUZZ)
		{
			emu.Fuzz();
			//writeln(emu.coverage, " ", emu.MINHALTCOUNT);
			//emu.MINHALTCOUNT = 0;
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
