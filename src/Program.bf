using System;
using System.Collections;
using System.Threading;
using System.Diagnostics;
using System.IO;
using SDL2;
namespace Playground_Lines;


//Philosophy:

//Struct constructors define values
//Class constructors only define how much data they need to allocate

class Program : SDLApp
{
	public static Self Instance;
	public static void Main() {
		delete (Instance = new Program())..PreInit()..Init()..Run();
	}

	public const int w = 1920/2;
	public const int h = 1080/2;

	Grid2<uint8[3]> finalImg = new .(w,h) ~ delete _;
	Grid2<float3> img = new .(w,h) ~ delete _;
	SDL.Surface* sdlSurface ~ SDL.FreeSurface(_);
	SDL2.Image sdlImage ~ delete _;
	ISim sim = new Sim1() ~ delete _;

	public this(): base() {}

	public override void Init() {
		base.Init();
		SDL2.SDL.SetWindowSize(Program.Instance.mWindow, Program.w, Program.h);
		mWidth = w;
		mHeight = h;

		sdlSurface = SDL.CreateRGBSurfaceWithFormatFrom(finalImg.raw.Ptr, (.)finalImg.width, (.)finalImg.height, 24, (.)finalImg.width * 3, SDL.PIXELFORMAT_RGB24);
		sdlImage = new .() {
			mWidth = (.)finalImg.width,
			mHeight = (.)finalImg.height
		};
	}

	Stopwatch watch = new .() ~ delete _;
	public override void Draw() {
		sim.OnFrame(float(watch.ElapsedMilliseconds)/1000, img);
		watch.Restart();

		Assets.FinalizeRGB24(.(img.raw.Ptr, img.raw.Count), finalImg.raw.Ptr);
		sdlImage.mTexture = SDL.CreateTextureFromSurface(mRenderer, sdlSurface); defer SDL.DestroyTexture(sdlImage.mTexture);
		Draw(sdlImage, 0, 0);
	}

	public override void Update() {
		sim.OnTick(1f/60);
	}
}
