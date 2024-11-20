using Playground;

namespace System
{
	extension Math
	{
		public static Vec3<T> Max<T>(Vec3<T> a, Vec3<T> b)
		where T: operator T+T, operator T-T, operator T*T, operator T/T, IIsNaN
		where bool: operator T<T
			=> .(Max(a.x, b.x), Max(a.y, b.y), Max(a.z, b.z));

		public static Vec3<T> Min<T>(Vec3<T> a, Vec3<T> b)
		where T: operator T+T, operator T-T, operator T*T, operator T/T, IIsNaN
		where bool: operator T<T
			=> .(Min(a.x, b.x), Min(a.y, b.y), Min(a.z, b.z));

		public static T Max<T>(T a, T b, T c) where bool : operator T < T where T : IIsNaN => Math.Max(Math.Max(a, b), c);
		public static T Min<T>(T a, T b, T c) where bool : operator T < T where T : IIsNaN => Math.Min(Math.Min(a, b), c);

		public static bool IsInRange(float min, float max, float v)
			=> min <= v && v <= max;

		//point of conflict. Shouldn't it return bool[3]?
		public static bool IsClamped(float3 min, float3 max, float3 v)
			=> IsInRange(min.x, max.x, v.x) && IsInRange(min.y, max.y, v.y) && IsInRange(min.z, max.z, v.z);

		public static float remap(float v, float min0, float max0, float min1, float max1)
			=> Math.Lerp(min1, max1, (v-min0)/(max0-min0));

		public static float3 remap(float3 v, float3 min0, float3 max0, float3 min1, float3 max1)
			=> .(remap(v.x, min0.x, max0.x, min1.x, max1.x),
				remap(v.y, min0.y, max0.y, min1.y, max1.y),
				remap(v.z, min0.z, max0.z, min1.z, max1.z));

		public static float2 transform(float2[3] matrix, float3 pos)
			=> pos.x * matrix[0] + pos.y * matrix[1] + pos.z * matrix[2];

		public static float2 transform(float2[3] matrix, float2 origin, float3 pos)
			=> transform(matrix, pos) + origin;
	}
}