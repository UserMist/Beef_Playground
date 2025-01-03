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
	RGB brushColor = .(1f, 1f, 1f);
	int brushRadius = 3;

	public this() {
		domain.Add(Camera(default, default));
		images.Add(new $"0", new .(1000,1000));
		for (var pixel in ref images["0"].cells) {
			//pixel.Value = .All(1);
		}
		imageKey.Set("0");
	}

	public override void Advance(float dt) => NOP!();
	public override void UpdateIO(float dt, IOConnection io) {
		double2 cursorPos = io.GetFirstAxis<2>(.("mx", "my"));
		double2 cursorOldPos = io.GetFirstAxisPrev<2>(.("mx", "my"));

		if (io.GetFirstAxis("radius") > 0) {
			brushRadius = Math.Max(1, (int) (cursorPos.y * 10));
		}
		let draw = io.GetFirstAxis("draw");
		let palette = io.GetFirstAxis("quick_palette");
		let paletted = io.GetFirstAxisPrev("quick_palette");
		let drew = io.GetFirstAxisPrev("draw");

		delegate RGB(RGB, float) shader = scope (pixel, proximity) => {
			return Math.Lerp(pixel.Value, brushColor, proximity == 0? 0 : 1);
		};

		if (images.GetValue(imageKey) case .Ok(var image)) {
			io.Render(domain, scope [&](canvas) => {
				canvas.image.EnsureSize(image.width, image.height);
				maxSize = .(image.width, image.height);
				strokeTileSize = brushRadius*2+1;
	
				if (draw > 0.5f) {
					addSubStroke(image.ClipToScreen(.(.(cursorOldPos.x), .(cursorOldPos.y))), image.ClipToScreen(.(.(cursorPos.x), .(cursorPos.y))), brushRadius);
					renderStroke(shader, image, canvas.image);
				} else if (drew > 0.5f) {
					renderStroke(shader, image, image);
					image.CopyTo(canvas.image);
					for (let v in strokeTiles.Values) delete v;
					strokeTiles.Clear();
				}

				if (palette > 0.5f && paletted < 0.5f) {
					for (let idx < image.cells.Count) {
						canvas.image.cells[idx] = pickRGB(image.ScreenToClip(.(idx % image.width, idx / image.height)));
					}
				} else if (palette < 0.5f && paletted > 0.5f) {
					brushColor = pickRGB((.)cursorPos.x, (.)cursorPos.y, 1);
					image.CopyTo(canvas.image);
				}
			});
		}
	}

	private static RGB pickRGB(float3 p) {
		return pickRGB(p.x, p.y, p.z);
	}

	private static RGB pickRGB(float x, float y, float z) {
		return .(Math.Max(x,0), Math.Max(y,0), 1);
	}

	private static void debug(int2 a, int2 b, int r) {
		Cage2<int>.CreateBounding(a, b);
	}

	private void addSubStroke(int2 a, int2 b, int r) {
		let tileSize = strokeTileSize; //2*r 
		var max = Math.Max(a, b);
		var min = Math.Min(a, b);
		max = (max + .All(r)) / tileSize;
		min = (min - .All(r)) / tileSize;
		min = .(Math.Max(min.x, 0), Math.Max(min.y, 0));

		let invR = float(uint16.MaxValue) / r;
		int2 tilePos = default;
		for (tilePos.y = min.y; tilePos.y <= max.y; tilePos.y++) for (tilePos.x = min.x; tilePos.x <= max.x; tilePos.x++) {
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

	private void renderStroke(delegate RGB(RGB pixel, float proximity) shader, Grid2<RGB> input, Grid2<RGB> output) {
		let inv = 1f / uint16.MaxValue;
		if (input != null) {
			let tileSize = strokeTileSize;
			for (let kv in strokeTiles) {
				let tilePos = kv.key;
				let tile = kv.value;
				let firstIdx = tilePos * tileSize;
				if (firstIdx.x > maxSize.x || firstIdx.y > maxSize.y) continue;
				let trimmedSize = Math.Min(firstIdx + int2.All(tileSize), maxSize) - firstIdx;
				for (let j < trimmedSize.y) for (let i < trimmedSize.x) {
					output[firstIdx + int2(i, j)] = shader(input[firstIdx + int2(i, j)], tile[j*tileSize + i]*inv);
				}
			}
		}
	}
}