namespace Playground.Data;
using System;

struct Cage2<T>: this(Vec2<T> min, Vec2<T> max)
where T: operator T+T, operator T-T, operator T*T, operator T/T
where bool: operator T<T
{
	public void Include(Vec2<T> p) mut {
		min = .(Math.Min(min.x, p.x), Math.Min(min.y, p.y));
		max = .(Math.Max(max.x, p.x), Math.Max(max.y, p.y));
	}

	public static Self CreateBounding(params Span<Vec2<T>> points) {
		Self ret = .(points[0], points[0]);
		for (var i = 1; i < points.Length; i++) {
			ret.Include(points[i]);
		}
		return ret;
	}

	static this() {
		let a = a(.All(0), .All(1));
	}

	private static void a(int2 v, int2 v1) {
		Cage2<int>.CreateBounding(v, v1);
	}
}

extension Cage2<T>
where T: float
{
	//public static AABB3<T> World => .(.All(float.NegativeInfinity), .All(float.PositiveInfinity));

	public Vec3<T> calculateCenter() {
		return (min + max) * 0.5f;
	}

	public Vec3<T> dimensions() {
		return max - min;
	}
}

struct Cage3<T>: this(Vec3<T> min, Vec3<T> max)
where T: operator T+T, operator T-T, operator T*T, operator T/T
where bool: operator T<T
{
}

extension Cage3<T>
where T: float
{
	//public static AABB3<T> World => .(.All(float.NegativeInfinity), .All(float.PositiveInfinity));

	public Vec3<T> calculateCenter() {
		return (min + max) * 0.5f;
	}

	public Vec3<T> dimensions() {
		return max - min;
	}
}