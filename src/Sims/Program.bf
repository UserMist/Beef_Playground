using System;
using System.Collections;
using System.Threading;
using System.Diagnostics;
using System.IO;
using System.Net;
using SDL2;
namespace Playground;


//Philosophy:

//Struct constructors define values
//Class constructors only define how much data they need to allocate

class Program : SDLApp
{
	public static Self Instance ~ Socket.Uninit();
	public static void Main() {
		Socket.Init();
		delete (Instance = new Program())..PreInit()..Init()..Run();
	}

	public const int2 windowSize = .(1920, 1080)*3/5;
	public const int2 pixelSize = .All(3);

	Grid2<uint8[3]> finalImg = new .(windowSize/pixelSize) ~ delete _;
	Grid2<float3> img = new .(windowSize/pixelSize) ~ delete _;
	SDL.Surface* sdlSurface ~ SDL.FreeSurface(_);
	SDL2.Image sdlImage ~ delete _;
	ISim sim = new Sim0() ~ delete _;

	public this(): base() {
		mTitle.Set("Playground");
	}

	public override void Init() {
		base.Init();
		mWidth = windowSize.x;
		mHeight = windowSize.y;
		SDL2.SDL.SetWindowSize(Program.Instance.mWindow, mWidth, mHeight);

		sdlSurface = SDL.CreateRGBSurfaceWithFormatFrom(finalImg.cells.Ptr, (.)finalImg.width, (.)finalImg.height, 24, (.)finalImg.width * 3, SDL.PIXELFORMAT_RGB24);
		sdlImage = new .() {
			mWidth = (.)finalImg.width,
			mHeight = (.)finalImg.height
		};

	}

	Stopwatch watch = new .() ~ delete _;
	public override void Draw() {
		sim.DrawFrame(float(watch.ElapsedMilliseconds)/1000, img);
		watch.Restart();

		AssetTools.FinalizeRGB24(.(img.cells.Ptr, img.cells.Count), finalImg.cells.Ptr);

		sdlImage.mTexture = SDL.CreateTextureFromSurface(mRenderer, sdlSurface); defer SDL.DestroyTexture(sdlImage.mTexture);
		DrawToWindow(sdlImage);
	}
	
	public void DrawToWindow(Image image)
	{
		SDL.SetRenderTarget(mRenderer, sdlImage.mTexture);
		SDL.Rect srcRect = .(0, 0, image.mWidth, image.mHeight);
		SDL.Rect destRect = .(0, 0, mWidth, mHeight);
		SDL.RenderCopy(mRenderer, image.mTexture, &srcRect, &destRect);
	}

	public override void Update() {
		sim.Advance(1f/60);
	}

	public override void KeyDown(SDL.KeyboardEvent evt)
	{
		sim.Act(base.KeyDown(..evt));
	}
}
