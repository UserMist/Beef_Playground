namespace Playground;

struct AABB3<T>: this(Vec3<T> min, Vec3<T> max)
where T: operator T+T, operator T-T, operator T*T, operator T/T
where bool: operator T<T
{
	
}

extension AABB3<T>
where T: float
{
	//public static AABB3<T> World => .(.All(float.NegativeInfinity), .All(float.PositiveInfinity));
}