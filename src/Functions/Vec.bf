using System;
namespace Playground;

struct Vec2<T>: this(T x, T y)
where T: operator T+T, operator T-T, operator T*T, operator T/T
{
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

	public static Self All(T v) => .(v, v);

	public static implicit operator Vec2<T>(T[2] value) => BitConverter.Convert<T[2], Vec2<T>>(value);
}

extension Vec2<T>: IHashable where T: int
{
	public int GetHashCode() {
		return (int(x) << 32) + y;
	}
}

struct Vec3<T>: this(T x, T y, T z = default)
where T: operator T+T, operator T-T, operator T*T, operator T/T
{
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

	public static Self All(T v) => .(v, v, v);

	public static implicit operator Vec3<T>(T[3] value) => BitConverter.Convert<T[3], Vec3<T>>(value);
}

extension Vec3<T> where T: operator -T
{
	public static Self operator -(Self a) => .(-a.x, -a.y, -a.z);
}

typealias double2 = Vec2<double>;
typealias double3 = Vec3<double>;
typealias float2 = Vec2<float>;
typealias float3 = Vec3<float>;
typealias int2 = Vec2<int>;
typealias int3 = Vec3<int>;