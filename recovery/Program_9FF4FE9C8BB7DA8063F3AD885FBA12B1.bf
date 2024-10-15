using System;
using System.IO;
using System.Collections;
using static System.Math;

namespace MinimalImageWriter;

struct Vec2<T>: this(T x, T y) where T: operator T+T, operator T-T, operator T*T, operator T/T {
	[Commutable] public static Self operator +(Self a, Self b) => .(a.x+b.x, a.y+b.y);
	public static Self operator -(Self a, Self b) => .(a.x-b.x, a.y-b.y);
	[Commutable] public static Self operator *(Self a, Self b) => .(a.x*b.x, a.y*b.y);
	public static Self operator /(Self a, Self b) => .(a.x/b.x, a.y/b.y);
	public static Self operator /(Self a, T b) => .(a.x/b, a.y/b);
	public static Self operator /(T a, Self b) => .(a/b.x, a/b.y);
	[Commutable] public static Self operator *(Self a, T b) => .(a.x*b, a.y*b);

	public static explicit operator Vec2<M><M>(Vec2<T> a)
		where M: operator M+M, operator M-M, operator M*M, operator M/M, operator explicit T
		=> .((.)a.x, (.)a.y);
}

struct Vec3<T>: this(T x, T y, T z) where T: operator T+T, operator T-T, operator T*T, operator T/T {
	[Commutable] public static Self operator +(Self a, Self b) => .(a.x+b.x, a.y+b.y, a.z+b.z);
	public static Self operator -(Self a, Self b) => .(a.x-b.x, a.y-b.y, a.z-b.z);
	[Commutable] public static Self operator *(Self a, Self b) => .(a.x*b.x, a.y*b.y, a.z*b.z);
	public static Self operator /(Self a, Self b) => .(a.x/b.x, a.y/b.y, a.z/b.z);
	public static Self operator /(Self a, T b) => .(a.x/b, a.y/b, a.z/b);
	public static Self operator /(T a, Self b) => .(a/b.x, a/b.y, a/b.z);
	[Commutable] public static Self operator *(Self a, T b) => .(a.x*b, a.y*b, a.z*b);

	public static implicit operator Vec3<T>(Vec2<T> a) => .(a.x, a.y, default);
	public static explicit operator Vec2<T>(Vec3<T> a) => .(a.x, a.y);

	public static explicit operator Vec3<M><M>(Vec3<T> a)
		where M: operator M+M, operator M-M, operator M*M, operator M/M, operator explicit T
		=> .((.)a.x, (.)a.y, (.)a.z);
}

typealias float2 = Vec2<float>;
typealias float3 = Vec3<float>;
typealias int2 = Vec2<int>;
typealias int3 = Vec3<int>;

class Program
{
	private static Vec3<T> Max<T>(Vec3<T> a, Vec3<T> b)
		where T: operator T+T, operator T-T, operator T*T, operator T/T, IIsNaN
		where bool: operator T>T {
		return .(Max(a.x, b.x), Max(a.y, b.y), Max(a.z, b.z));
	}

	private static Vec3<T> Min<T>(Vec3<T> a, Vec3<T> b)
		where T: operator T+T, operator T-T, operator T*T, operator T/T, IIsNaN
		where bool: operator T>T {
		return .(Min(a.x, b.x), Min(a.y, b.y), Min(a.z, b.z));
	}

	private static T Max<T>(T a, T b, T c) where bool : operator T > T where T : IIsNaN => Math.Max(Math.Max(a, b), c);
	private static T Max<T>(T a, T b) where bool : operator T > T where T : IIsNaN => Math.Max(a, b);
	private static T Min<T>(T a, T b, T c) where bool : operator T > T where T : IIsNaN => Math.Min(Math.Min(a, b), c);
	private static T Min<T>(T a, T b) where bool : operator T > T where T : IIsNaN => Math.Min(a, b);

	private static void drawLineUnsafe<T>(Grid2<T> grid, int2 a, int2 b, T color) {
		let dx = Math.Abs(b.x - a.x);
		let dy = -Math.Abs(b.y - a.y);
		let sx = a.x < b.x? 1 : -1;
		let sy = a.y < b.y? 1 : -1;

		var a;
		var e = dx + dy;
		while (true) {
			grid[a] = color;

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

	public static bool RayBoxIntersection(float3 rayOrigin, float3 rayDirection, float3 boxMin, float3 boxMax, out float minDist, out float maxDist) {
	  //Note that having rayOrigin inside box is also valid.
		float3 m = 1f/rayDirection;
	  let distsToMin = (boxMin - rayOrigin)*m;
	  let distsToMax = (boxMax - rayOrigin)*m;
	  float3 frontDists = Min(distsToMin, distsToMax);
	  float3 backDists = Max(distsToMin, distsToMax);
	  minDist = Max(frontDists.x, frontDists.y, frontDists.z); //distance to plane-triplet that is furthest behind our back
	  maxDist = Min(backDists.x, backDists.y, backDists.z); //distance to plane-triplet that is furthest to the front 
	  //When directional line misses box, distB < distA.
	  //To turn directional line into a ray, also add check of distB > 0
	  return minDist < maxDist && maxDist > 0;
	}

	private static void drawLine<T>(Grid2<T> grid, int2 a, int2 b, T color) {
		let pos = float3(a.x, a.y, 0);
		let vec = float3(b.x-a.x, b.y-a.y, 0);
		let length = Math.Sqrt(vec.x*vec.x + vec.y*vec.y + vec.z*vec.z);
		if (length < 1) { if(a.x < grid.width && a.y < grid.height && a.x >= 0 && a.y >= 0) grid[a] = color; return; }
		let dir = vec / length;

		RayBoxIntersection(.(a.x, a.y, 0), dir, .(0, 0, -1), .(grid.width-1, grid.height-1, 1), var minDist, var maxDist);
		let lineHits = minDist < maxDist;
		if (lineHits && maxDist > 0 && minDist <= length) {
			let newAP = pos + dir * Max(0, minDist);
			let newBP = pos + dir * Min(length, maxDist);
			if (newAP.x.IsNaN || newAP.y.IsNaN) return;
			let newA = int2((.)Math.Round(newAP.x), (.)Math.Round(newAP.y));
			let newB = int2((.)Math.Round(newBP.x), (.)Math.Round(newBP.y));
			drawLineUnsafe(grid, newA, newB, color);
		}
	}

	public class Grid2<T> {
		public int width;
		public int height;
		public T[] raw ~ delete _;

		public T this[int2 xy] {
			get => raw[xy.x + xy.y * width];
			set => raw[xy.x + xy.y * width] = value;
		}

		public T this[int x, int y] {
			get => raw[x + y * width];
			set => raw[x + y * width] = value;
		}

		public this(int width, int height) {
			this.width = width;
			this.height = height;
			raw = new .[width*height];
		}

		public void Set(Grid2<T> image) {
			width = image.width;
			height = image.height;
			image.raw.CopyTo(raw = new .[image.raw.Count]);
		}

		public void Set(T col) {
			for (let i < raw.Count) raw[i] = col;
		}

		public void CopyTo(Grid2<T> to, int2 at = .(0,0)) {
			for (var j < height) {
				for (var i < width) {
					to[i+at.x, j+at.y] = this[i, j];
				}
			}
		}

		public void Map(function T(T col) f) {
			for (let i < raw.Count) {
				raw[i] = f(raw[i]);
			}
		}
	}

	class Image {
		Grid2<float3> pixels;
		bool isMirrored;
		double turns;
	}

	private static void saveTga(FileStream file, Grid2<float3> rgb, uint8 bitDepth = 24, bool fromBottom = false, bool fromRight = false) {
		uint8 alphaDepth = 0;
		uint8[18] header = default;
		header[2] = 2;
		header[12] = uint8(rgb.width);
		header[13] = uint8(rgb.width >> 8);
		header[14] = uint8(rgb.height);
		header[15] = uint8(rgb.height >> 8);
		header[16] = bitDepth;
		header[17] = alphaDepth | (fromRight? 16:0) | (fromBottom? 0:32);
		file.Write(header);

		switch (bitDepth) {
		case 24:
			let area = rgb.width * rgb.height;
			String str = new .(area*3); defer delete str;
			str.[Friend]mLength = .(area*3);
			var j = 0;
			for (let i < area) {
				let r = uint8(Math.Clamp(Math.Pow(rgb.raw[i].x, 0.454f) * 255, 0, 255));
				let g = uint8(Math.Clamp(Math.Pow(rgb.raw[i].y, 0.454f) * 255, 0, 255));
				let b = uint8(Math.Clamp(Math.Pow(rgb.raw[i].z, 0.454f) * 255, 0, 255));
				str[j++] = char8(b);
				str[j++] = char8(g);
				str[j++] = char8(r);
			}
			file.Write(str);
		default: ThrowUnimplemented();
		}
	}

	static int2 toPixelPos<T>(Grid2<T> grid, float2 pos) {
		return toPixelPos(.(grid.width, grid.height), pos);
	}

	static int2 toPixelPos(int2 dim, float2 pos) {
		var ret = (pos + .(1,-1)) * 0.5f * (.)dim;
		return .(int(ret.x), -int(ret.y));
	}

	static float2 getScreenPos<T>(Grid2<T> grid, int2 pos) {
		return getScreenPos(.(grid.width, grid.height), pos);
	}

	static float2 getScreenPos(int2 dim, int2 pos) {
		return .(float(2 * pos.x) / dim.x - 1, 1 - float(2 * pos.y) / dim.y);
	}

	static float2 to2d(float2[3] matrix, float3 pos)
		=> pos.x * matrix[0] + pos.y * matrix[1] + pos.z * matrix[2];

	static float2 to2d(float2[3] matrix, float2 origin, float3 pos) {
		return to2d(matrix, pos) + origin;
	}

	struct Tracer {
		public int2? p;

		public void supply<T>(Grid2<T> img, int2 p2, T col) mut {
			if (p.HasValue)
				drawLine(img, p.ValueOrDefault, p2, col);
			p = p2;
		}
	}

	public static void Main() {
		let seed = 15;
		for (let i < 1) {
			rng = scope .(seed);
			genFrameCollage(i);
		}
	}

	public static void genFrameCollage(int frame) {
		let w = 1920/4;
		let h = 1080/4;
		let finalImg = scope Grid2<float3>(w*4,h*4); defer saveTga(scope FileStream()..Open(scope $"E:/test_{frame}.tga", .OpenOrCreate, .Write), finalImg);
		for (let i < 4) for (let j < 4) {
			let img = genFrame(frame, i, w, h);
			img.CopyTo(finalImg, .(finalImg.width*i/4, finalImg.height*j/4));
			delete img;
		}
	}

	static float remap(float v, float min0, float max0, float min1, float max1) {
		return Math.Lerp(min1, max1, (v-min0)/(max0-min0));
	}

	static float3 remap(float3 v, float3 min0, float3 max0, float3 min1, float3 max1) {
		return .(remap(v.x, min0.x, max0.x, min1.x, max1.x),
			remap(v.y, min0.y, max0.y, min1.y, max1.y),
			remap(v.z, min0.z, max0.z, min1.z, max1.z));
	}

	static Random rng;
	static float rand() {
		return .(rng.NextDouble()*2-1);
	}

	public static Grid2<float3> genFrame(int frame, int mainidx, int width, int height) {
		let img = new Grid2<float3>(width, height);
		let dim = int2(img.width, img.height);

		for (let j < img.height) for (let i < img.width) {
			let p = (float3)getScreenPos(dim, .(i,j));
			//img[i, j] = Math.Lerp(float3(0,0.004f,0.007f), float3(0,0,0), Math.Sqrt(p.x*p.x + p.y*p.y)*0.5f);
			img[i, j] *= 0.5f;
		}


		List<Tracer> tracers = scope .();
		List<float3> p = scope .();
		List<float3> v = scope .();

		List<List<(float3 pos, float3 vel)>> trajectories = new .(); defer {DeleteContainerAndItems!(trajectories);}

		for (let i < 3) {
			tracers.Add(.());
			p.Add(.(rand(), rand(), rand() * 0.01f)*0.5f);
			v.Add(.(rand(), rand(), rand() * 0.01f)*0.4f);
			trajectories.Add(new .());
		}

		let dt = 0.01f;
		for (var t = 0f; t <= 10; t += dt) {
			for (let i < p.Count) {
				v[i] *= Math.Exp(-0.1f*dt);
				for (let j < p.Count) {
					if (i == j) continue;
					let dp = (p[i] - p[j]);
					let len = Math.Sqrt(dp.x*dp.x + dp.y*dp.y + dp.z*dp.z);
					v[i] += dp/(len*len)*dt*-0.1f;
				}
			}

			for (let i < p.Count) {
				trajectories[i].Add((p[i], v[i]));
				p[i] += v[i] * dt; 
			}
		}

		float3 frameMin = .(float.PositiveInfinity, float.PositiveInfinity, 0);
		float3 frameMax = .(float.NegativeInfinity, float.NegativeInfinity, 0);

		for (let traj in trajectories) for (let trajDot in traj) {
			if (trajDot.pos.x.IsNaN || trajDot.pos.y.IsNaN || trajDot.pos.z.IsNaN) continue;
			frameMin = Min(frameMin, trajDot.pos);
			frameMax = Max(frameMax, trajDot.pos);
		}

		int maxTrajLength = 0;
		for (let traj in trajectories) maxTrajLength = Max(maxTrajLength, traj.Count);

		for (let i < maxTrajLength) {
			//for (var sdlf in ref img.raw) {
				//sdlf *= 0.99f;
			//}
			img.Map((c) => c*0.99f);

			for (let j < trajectories.Count) {
				if (i >= trajectories[j].Count) continue;
				let trajDot = trajectories[j][i];

				let bias = width/10;
				let ppos = remap(trajDot.pos, frameMin, frameMax, .(bias,bias,0), .(img.width-bias, img.height-bias,0));
				tracers[j].supply(img, .((.)ppos.x, (.)ppos.y), (trajDot.vel + .(0.5f, 0.5f, 0))*2f);
			}
		}
		
		let cc = float3(0.25f,0.25f,0.25f);
		drawLine(img, .(width-1, 0), .(width-1, height-1), cc);
		drawLine(img, .(0, height-1), .(width-1, height-1), cc);
		drawLine(img, .(0,0), .(width-1,0), cc);
		drawLine(img, .(0,0), .(0,height-1), cc);

		return img;

		/*int2? prev = null;
		for (var t = 0f; t <= 100; t += 0.01f) {

			float[3] p = .
				(Cos(t*16)*0.2f*t
				,Sin(t*16)*0.2f*t
				,t*0.1f
			);

			let col = float[3]
				(0.5f+0.5f*Cos(6*t)
				,1
				,1
			);

			let cur = toPixelPos(dim, to2d(.(.(1,0), .(0.2f,0.8f), .(0,1f)), p)); defer { prev = cur; }
			if (prev.HasValue) drawLine(img, prev.Value, cur, col);
		}*/
	}
}