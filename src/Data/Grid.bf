using System;
using static System.Math;
namespace Playground;

public class Grid2<T>
{
	[Inline] public int width => cells.GetLength(1);
	[Inline] public int height => cells.GetLength(0);
	public T[,] cells ~ delete _;

	public this(int2 wh) {
		cells = new .[wh.y, wh.x];
	}

	public this(int width, int height) {
		cells = new .[height, width];
	}

	public T this[int rawX, int rawY] {
		get => cells[rawY, rawX];
		set => cells[rawY, rawX] = value;
	}

	public T this[int2 rawXY] {
		get => cells[rawXY.y, rawXY.x];
		set => cells[rawXY.y, rawXY.x] = value;
	}

	public void Reset(T value) {
		let c = cells.Count;
		for (let i < c)
			cells[i] = value;
	}

	public void Set(Grid2<T> image) {
		//image.array.CopyTo(array = new .[image.array.Count]);
		ThrowUnimplemented();
	}

	public void CopyTo(Grid2<T> that, int2 atRaw = .(0, 0)) {
		let c0 = width;
		let c1 = height;
		for (var j < c1)
			for (var i < c0)
				that[int2(i + atRaw.x, j + atRaw.y)] = this[int2(i, j)];
	}

	public void Map(function T(T value) f) {
		let c = cells.Count;
		for (let i < c)
			cells[i] = f(cells[i]);
	}

	public T GetPoint(float2 a) {
		return this[ClipToScreen(a)];
	}

	public void DrawTriangle(float3[3] verts, delegate T(float3 clipCoords) method) {
		var verts;
		if (verts[0].y > verts[1].y) Swap!(verts[0], verts[1]);
		if (verts[1].y > verts[2].y) Swap!(verts[1], verts[2]);
		if (verts[0].y > verts[1].y) Swap!(verts[0], verts[1]);


	}

	private void drawTriangleUnsafe(float3[3] ord, delegate T(float3 clipCoords) method) {
		let p = int3[3]((.)(ord[0] + .All(0.5f)), (.)(ord[1] + .All(0.5f)), (.)(ord[2] + .All(0.5f)));

		if (p[0].y != p[1].y) {
			for (var y = p[0].y; y <= p[1].y; y++) {
				var x02 = int(0.5f + (ord[2].x - ord[0].x) * (y - ord[0].y) / (ord[2].y - ord[0].y));
				var x01 = int(0.5f + (ord[1].x - ord[0].x) * (y - ord[0].y) / (ord[1].y - ord[0].y));
				if (x02 < x01) Swap!(x01, x02);
				for (var x = x01; x <= x02; x++)
					this[x,y] = method(default);
			}
		} else {
			var x01 = p[0].x;
			var x02 = p[1].x;
			if (x02 < x01) Swap!(x01, x02);

			for (var x = x01; x <= x02; x++) {
				this[x,p[0].y] = method(default);
			}
		}

		if (p[1].y != p[2].y) {
			for (var y = p[1].y; y <= p[2].y; y++) {
				var x02 = int(0.5f + (ord[2].x - ord[0].x) * (y - ord[0].y) / (ord[2].y - ord[0].y));
				var x12 = int(0.5f + (ord[2].x - ord[1].x) * (y - ord[1].y) / (ord[2].y - ord[1].y));
				if (x02 < x12) Swap!(x12, x02);
				for (var x = x12; x <= x02; x++)
					this[x,y] = method(default);
			}
		}
	}

	/// Uses Bresenham's algorithm
	public void DrawLine(float3[2] verts, T value) {
		DrawLine(verts[0], verts[1], value);
	}

	//todo: check if float3 converts properly to int3 (no wraparound)
	/// Uses Bresenham's algorithm
	public void DrawLine(float3 a, float3 b, T value) {
		if (ClipToScreen((.) b) == ClipToScreen((.) a)) {
			DrawPoint(a, value);
			return;
		}
		
		let vec = b - a;
		let length = Sqrt(vec.x*vec.x + vec.y*vec.y + vec.z*vec.z);
		let dir = vec / length;

		let isHitting = ShapeTools.RayBoxIntersection(a * 0.9999999f, dir, .All(-1), .All(1), let minDist, let maxDist);
		if (isHitting && minDist <= length) {
			let aClip = a + dir*Max(minDist, 0);
			let bClip = a + dir*Min(maxDist, length);
			if (aClip.x.IsNaN || aClip.y.IsNaN) return;
			drawLineUnsafe(ClipToScreen((.) aClip), ClipToScreen((.) bClip), value);
		}
	}
	
	public void DrawPoint(float3 a, T value) {
		if (a.x > +1 || a.x < -1 || a.y > +1 || a.y < -1 || a.z > +1 || a.z < -1 ) {
			return;
		}

		this[ClipToScreen((.) a)] = value;
	}

	public int2 ClipToScreen(float2 p) {
		var p;
		p.y = -p.y;
		p += .All(1);
		p *= .(width - 1, height - 1);
		p *= 0.5f;
		return int2((.)Round(p.x), (.)Round(p.y));
	}

	public float2 ScreenToClip(int2 p) {
		var p;
		p *= 2;
		var p2 = (float2) p;
		p2 /= .(width - 1, height - 1);
		p2 -= .All(1);
		p2.y = -p.y;
		return p2;
	}

	private void drawLineUnsafe(int2 a, int2 b, T color) {
		let dx = Abs(b.x - a.x);
		let dy = -Abs(b.y - a.y);
		let sx = (a.x < b.x)? 1 : -1;
		let sy = (a.y < b.y)? 1 : -1;
		
		var a;
		var e = dx + dy;
		while (true) {
			this[a] = color;

			if (a == b) break;
			let e2 = 2*e;

			if (e2 >= dy) {
				if (a.x == b.x) break;
				e += dy;
				a.x += sx;
			}

			if (e2 <= dx) {
				if (a.y == b.y) break;
				e += dx;
				a.y += sy;
			}
		}
	}
}

extension Grid2<T>
where T: operator T+T, operator T-T, operator T*T, operator T/T
{

}