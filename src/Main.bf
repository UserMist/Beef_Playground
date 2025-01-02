using System;
using System.Collections;
using System.Threading;
using System.Diagnostics;
using System.IO;
using System.Net;
using SDL2;
using Playground.Data;
using Playground.Data.Entity;
using Playground.Data.Entity.Components;
namespace Playground;


//Philosophy:

//Struct constructors define values
//Class constructors only define how much data they need to allocate

class Main : SDLApp
{
	public static Self Instance ~ Socket.Uninit();
	public static void Main() {
		Socket.Init();
		delete (Instance = new Main())..PreInit()..Init()..Run();
	}

	public const int2 windowSize = .(16, 16);
	public const int2 pixelSize = .All(1);//.All(3);

	Grid2<uint8[3]> finalImg = new .(windowSize/pixelSize) ~ delete _;
	Grid2<RGB> img = new .(windowSize/pixelSize) ~ delete _;
	SDL.Surface* sdlSurface;
	SDL2.Image sdlImage;


	public EntityDomain ioBuffer = new EntityDomain() ~ delete _;
	Subprogram sim = new ImageEditor() ~ delete _;
	EntityId ioEntity;

	private HashSet<SDL.Scancode> heldKeys = new .() ~ delete _;
	private Dictionary<String, List<(IOScan code, bool subtract)>> inputForwarders = new .() ~ DeleteDictionaryAndValues!(_);

	private enum IOScan {
		case None;
		case Key(SDL.Scancode);
		case MButton(int);
		case MAxis(int);
	}

	public ~this() {
		deinitWindowTexture();
	}

	public this(): base() {
		mTitle.Set("Playground");

		ioEntity = ioBuffer.Add(IOCanvas(img, default));
		ioBuffer.Refresh();
		sim.InitIOConnection(.(ioEntity, ioBuffer));
	}

	public override void Init() {
		base.Init();
		mWidth = windowSize.x;
		mHeight = windowSize.y;
		initWindowTexture();

		addBind("mx", .MAxis(0));
		addBind("my", .MAxis(1));

		addBind("draw", .MButton(0));

		ioBuffer.Add(IOAxis("radius", 8, 0));

		ioBuffer.Refresh();
	}

	private void initWindowTexture() {
		SDL2.SDL.SetWindowSize(Main.Instance.mWindow, mWidth, mHeight);
		sdlSurface = SDL.CreateRGBSurfaceWithFormatFrom(finalImg.cells.Ptr, (.)finalImg.width, (.)finalImg.height, 24, (.)finalImg.width * 3, SDL.PIXELFORMAT_RGB24);
		sdlImage = new .() {
			mWidth = (.)finalImg.width,
			mHeight = .(finalImg.height)
		};
	}

	private void deinitWindowTexture() {
		SDL.FreeSurface(sdlSurface);
		delete sdlImage;
	}

	Stopwatch watch = new .() ~ delete _;
	private int2 prevSize;
	public override void Draw() {
		prevSize = int2(img.width, img.height);
		prepareIO();
		sim.UpdateIO(float(watch.ElapsedMilliseconds)/1000, .(ioEntity, ioBuffer));
		if (prevSize.x != img.width || prevSize.y != img.height) {
			mWidth = .(img.width*pixelSize.x);
			mHeight = .(img.height*pixelSize.y);
			finalImg.EnsureSize(img.width, img.height);
			deinitWindowTexture();
			initWindowTexture();
		}
		watch.Restart();
		
		AssetTools.FinalizeRGB24(Span<RGB>(img.cells.Ptr, img.cells.Count), finalImg.cells.Ptr);

		sdlImage.mTexture = SDL.CreateTextureFromSurface(mRenderer, sdlSurface); defer SDL.DestroyTexture(sdlImage.mTexture);
		DrawToWindow(sdlImage);
	}
	
	public override void KeyDown(SDL.KeyboardEvent evt)
		=> heldKeys.Add(evt.keysym.scancode);

	public override void KeyUp(SDL.KeyboardEvent evt)
		=> heldKeys.Remove(evt.keysym.scancode);
	
	public void DrawToWindow(Image image) {
		SDL.SetRenderTarget(mRenderer, sdlImage.mTexture);
		SDL.Rect srcRect = .(0, 0, image.mWidth, image.mHeight);
		SDL.Rect destRect = .(0, 0, mWidth, mHeight);
		SDL.RenderCopy(mRenderer, image.mTexture, &srcRect, &destRect);
	}

	public override void Update() {
		sim.Advance(1f/60);
	}

	void addBind(String axisName, IOScan pos, IOScan neg = .None) {
		if (!inputForwarders.ContainsKey(axisName))
			inputForwarders.Add(axisName, new .());

		if (pos != .None) inputForwarders[axisName].Add((pos, false));
		if (neg != .None) inputForwarders[axisName].Add((neg, true));

		bool contains = false;
		ioBuffer.For("IOAxis").Run(scope [&](axis) => {
			if (axis.name == axisName)
				contains = true;
		});

		if (!contains)
			ioBuffer.Add(IOAxis(axisName, 0, 0));
		ioBuffer.Refresh();
	}

	void prepareIO() {
		Vec2<int32> mousePosRaw;
		let mouseState = SDL2.SDL.GetMouseState(out mousePosRaw.x, out mousePosRaw.y);
		let mousePos = ((double2) mousePosRaw / double2(mWidth, mHeight) - .All(0.5f)) * double2(2,-2);
		for (let bind in inputForwarders) {
			var value = 0.0;
			var count = 0;
			for (let k in bind.value) {
				if (k.code case .Key(let kcode) && heldKeys.Contains(kcode)) {
					value += k.subtract? -1 : +1;
				} else if (k.code case .MButton(let mcode) && SDL.BUTTON(.(mcode+1)) & mouseState > 0) {
					value += k.subtract? -1 : +1;
				} else if (k.code case .MAxis(let acode)) switch (acode) {
					case 0: value = k.subtract? -mousePos.x : mousePos.x;
					case 1: value = k.subtract? -mousePos.y : mousePos.y;
				}
				count++;
			}
			value /= count;

			if (count == 0)
				value = 0;

			ioBuffer.For("ref IOAxis").Run(scope (axis) => {
				if (axis.name != bind.key)
					return;

				let old = axis.value;
				axis.value = value;
				axis.delta = axis.value - old;
			});
		}
	}
}
