using static System.Math;
namespace Playground_Lines;

public class Grid2<T> {
	public int width => cells.GetLength(1);
	public int height => cells.GetLength(0);
	public T[,] cells ~ delete _;

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

	const System.StringView sv = "this[a] = color;";


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
			drawLineUnsafe<const sv>(ClipToScreen((.) aClip), ClipToScreen((.) bClip), value);
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
		return p2 -= .All(1);
	}

	private void drawLineUnsafe<S>(int2 a, int2 b, T color) where S: const System.StringView {
		let dx = Abs(b.x - a.x);
		let dy = -Abs(b.y - a.y);
		let sx = (a.x < b.x)? 1 : -1;
		let sy = (a.y < b.y)? 1 : -1;
		
		var a;
		var e = dx + dy;
		while (true) {
			System.Compiler.Mixin(S);

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