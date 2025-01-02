namespace Playground;

using System;
using System.Collections;
using Playground.Data;
using Playground.Data.Entity;
using Playground.Data.Entity.Components;
using static System.Math;

class ImageEditor: Subprogram
{
	public Dictionary<String, Grid2<RGB>> images = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
	public String imageKey = new .() ~ delete _;

	public int2 maxSize;
	public int strokeTileSize;
	public Dictionary<int2, uint16[]> strokeTiles = new .() ~ DeleteDictionaryAndValues!(_); //stores currently drawn stroke, each pixel stores biggest proximity to cursor

	public this() {
		domain.Add(Camera(default, default));
		images.Add(new $"0", new .(1000,1000));
		imageKey.Set("0");
	}

	public override void Advance(float dt) => NOP!();
	public override void UpdateIO(float dt, IOConnection io) {
		double2 cursorPos = io.GetFirstAxis<2>(.("mx", "my"));
		double2 cursorOldPos = io.GetFirstAxisPrev<2>(.("mx", "my"));
		let radius = Math.Max(0, (int)io.GetFirstAxis("radius"));
		let draw = io.GetFirstAxis("draw");
		let drew = io.GetFirstAxisPrev("draw");

		if (images.GetValue(imageKey) case .Ok(let image)) {
			/*io.Render(domain, scope (canvas) => {
				canvas.DrawLine((.)cursorPos, (.)cursorOldPos, RGB(255, 255, 255));
			});*/
			maxSize = .(image.width, image.height);

			if (draw > 0.5f) {
				debug(int2(0,0), int2(0,0), 1);
				//addSubStroke(image.ClipToScreen(.(.(cursorOldPos.x), .(cursorOldPos.y))), image.ClipToScreen(.(.(cursorPos.x), .(cursorPos.y))), radius);
			} else if (drew > 0.5f) {
				submitStroke(scope (srcPixel, dist) => *srcPixel = .(1,1,1));
			}

			io.Render(domain, scope (canvas) => {
				canvas.image.EnsureSize(image.width, image.height);
				image.CopyTo(canvas.image);
			});
		}
	}

	private void drawCircle(Grid2<RGB> image, Vec2<int> pos, int radius) {
		for (var j = -radius; j <= radius; j++) for (var i = -radius; i <= radius; i++) if (j*j + i*i < radius*radius) {
			let coord = int2(i,j) + pos;
			image[coord].Value = Math.Lerp(image[coord].Value, float3(0.5f,0.5f,0.5f), 0.25f);
		}
	}

	private static void debug(int2 a, int2 b, int r) {
		Cage2<int>.CreateBounding(a, b);
	}

	private void addSubStroke(int2 a, int2 b, int r) {
		let tileSize = strokeTileSize; //2*r 
		var cage = Cage2<int>.CreateBounding(a, b);
		cage.max = (cage.max + .All(r)) / tileSize;
		cage.min = (cage.min - .All(r)) / tileSize;
		cage.min = .(Math.Max(cage.min.x, 0), Math.Max(cage.min.y, 0));
		cage.max = .(Math.Min(cage.min.x, 0), Math.Min(cage.min.y, 0));

		let invR = float(uint16.MaxValue) / r;
		int2 tilePos = default;
		for (tilePos.y = cage.min.y; tilePos.y <= cage.max.y; tilePos.y++) for (tilePos.x = cage.min.x; tilePos.x <= cage.max.x; tilePos.x++) {
			if (!strokeTiles.ContainsKey(tilePos)) {
				strokeTiles[tilePos] = new .[tileSize*tileSize];
			}

			let tile = strokeTiles[tilePos];
			for (let idx < tile.Count) {
				let p = tilePos * tileSize + int2(idx % tileSize, idx / tileSize);
				let proximity = Math.Clamp(uint16.MaxValue - invR*SDF2.CapsuleF(.(p.x, p.y), .(a.x, a.y), .(b.x, b.y)), 0, uint16.MaxValue);
				tile[idx] = Math.Max(tile[idx], .(proximity));
			}
		}
	}

	private void submitStroke(delegate void(RGB* srcPixel, float dist) shader) {
		let inv = 1f / uint16.MaxValue;
		if (images.GetValue(imageKey) case .Ok(let image)) {
			let tileSize = strokeTileSize; //2*r 
			for (let kv in strokeTiles) {
				let tilePos = kv.key;
				let tile = kv.value;
				let trimmedSize = Math.Min(tilePos * tileSize + int2(tileSize, tileSize), maxSize);
				let skip = tileSize - trimmedSize.x;
				let max = trimmedSize.y * tileSize;
				for (var idx < max) {
					let p = tilePos * tileSize + int2(idx % tileSize, idx / tileSize);
					shader(&image[p], 1f - tile[idx]*inv);
					idx += skip;
				}
				delete tile;
			}
		} else for (let v in strokeTiles.Values) {
			delete v;
		}
		strokeTiles.Clear();
	}
}