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
string currom = "rom.bin";

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
		glBlendColor4ub(0,0,0,64);
		ubyte* dp = emu.display.ptr;
		for(int i = 0; i < 64; i++)
		{
			glRasterPos2i(0,i);
			glBitmap(192,1,0,0,0,0,(cast(GLubyte*)dp+i*32));
		}
		glBlendColor4ub(0,0,0,128);
		dp = emu.display.ptr + 0x800;
		for(int i = 0; i < 64; i++)
		{
			glRasterPos2i(0,i);
			glBitmap(192,1,0,0,0,0,(cast(GLubyte*)dp+i*32));
		}
		glTranslatef(-1,-1,0);
	}
}

string[64] labels = ["     ","SETUP","SHIFT","  x  ", " (-) ", "  7  ","  4  ","  1  ",
"MODE ","BACK "," VAR ","frac "," sin ","  8  ","  5  ","  2  ",
"     ", "LEFT ","f(x) ","sqrt "," cos ","  9  ","  6  ","  3  ",
"  UP ","  OK ","DOWN "," x^( "," tan "," DEL ", "  *  ", "  +  ",
"     ","RIGHT","CATLG"," x^2 ","  (  "," AC  ","  /  ", "  -  ",
" /\\  "," \\/  ","TOOLS","log_n","  )  ","     ","     ","     ",
"     ","     ","     ","  0  ","  .  ","*10^x","FORM.","  =  ",
"     ","     ","     ","     ","     ","     ","     ","     "];

class MainApp : Panel
{
	this(Panel parent)
	{
		super(parent);
		content = new Panel(this);
		screen = new Display(content);
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
	
	void LoadRom(Button b)
	{
		currom = b.text;
		emu.Init(currom);
	}
	
	void PressON()
	{
		emu.ULTRAHALT = false;
		emu.HALT = false;
		emu.Init(currom);
	}
	
	void PressButton(Button b)
	{
		int i = 0;
		foreach(Button check; buttons)
		{
			if(check == b)
			{
				emu.buttons[i>>3] |= 1<<(7-(i&0x7));
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
		ON.x = 256;
		ON.y = 4;
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
	
	mainpanel = new Window();
	
	app = new MainApp(mainpanel);
	
	mainpanel.inner.destroy();
	mainpanel.inner = app;
	
	emu.Init("rom.bin");
	
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
		
		emu.Tick();
		
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
