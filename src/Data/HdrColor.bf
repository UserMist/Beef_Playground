using System;
using System.Diagnostics;
namespace Playground.Data;

public struct GammaRGB
{
	private uint8[3] mantissas;

	public this() {
		this = default;
	}

	public this(float3 color) {
		this = ?;
		Value = color;
	}

	public this(float r, float g, float b) {
		this = ?;
		Value = float3(r,g,b);
	}

	public float3 Value {
		get {
			const float mul = 1f/255;
			return .(
				mul*Math.Pow(mantissas[0], 2.2f),
				mul*Math.Pow(mantissas[1], 2.2f),
				mul*Math.Pow(mantissas[2], 2.2f)
			);
		}
		set mut {
			const float toGamma = 1/2.2f;
			mantissas = .(
				(.)(0.5f + 255*Math.Pow(Math.Clamp(value.x, 0, 1), toGamma)),
				(.)(0.5f + 255*Math.Pow(Math.Clamp(value.y, 0, 1), toGamma)),
				(.)(0.5f + 255*Math.Pow(Math.Clamp(value.z, 0, 1), toGamma))
			);
		}
	};
}

public struct RGB
{
	public const float FloatMaxValue = calculateMaxValue();
	private static float calculateMaxValue() => RGB() { mantissas = .(255,0,0), exponent = 62 }.Value.x;
	public const float FloatEpsilon = calculateEpsilon();
	private static float calculateEpsilon() => RGB() { mantissas = .(1,0,0), exponent = -62 }.Value.x;

	private uint8[3] mantissas;
	private int8 exponent; //[-63; +63]

	public this() {
		this = default;
	}

	public this(float3 color) {
		this = ?;
		Value = color;
	}

	public this(float r, float g, float b) {
		this = ?;
		Value = float3(r,g,b);
	}

	public float3 Value {
		get {
			const float c = 1f/255f;
			let mul = BitConverter.Convert<uint32,float>(.(exponent + 127) << 23) * c;
			return .(
				int(mantissas[0])*mul,
				int(mantissas[1])*mul,
				int(mantissas[2])*mul
			);
		}

		set mut {
			var value;
			value.x = Math.Clamp(value.x, 0, FloatMaxValue);
			value.y = Math.Clamp(value.y, 0, FloatMaxValue);
			value.z = Math.Clamp(value.z, 0, FloatMaxValue);
			let expF32 = uint8(BitConverter.Convert<float,uint32>(Math.Max(value.x, value.y, value.z)) >> 23);
			let exp = int8(expF32 - 126);
			let mul = (exp < -63)? 0 : BitConverter.Convert<uint32,float>(.(253-expF32) << 23) * 255;
			exponent = (exp < -63)? 0 : exp;
			mantissas[0] = (.)Math.Round(value.x*mul);
			mantissas[1] = (.)Math.Round(value.y*mul);
			mantissas[2] = (.)Math.Round(value.z*mul);
		}
	};

	public static implicit operator Self(float3 x) => RGB(x);
	public static implicit operator float3(Self x) => x.Value;

	[Test]
	private static void test() {
		test(0, 0.5f, 0.9f);
		test(0, 0.5f, 1f);
		test(0, 0, 0);
		test(0, 0, float.Epsilon);
		test(0, 0, 60*float.Epsilon);
		test(0.1f, 0.5f, 9f);
		test(1000f, 0.5f, 9f);
		test(0.36267814f, 1, 0.36267814f);
		test(0.3f, 0.5f, 1f);
	}

	private static void test(float x, float y, float z) {
		let a = Self(float3(x, y, z)).Value;
		var maxOld = Math.Max(x, y, z);
		var maxNew = Math.Max(a.x, a.y, a.z);

		if (maxOld < FloatEpsilon)
			 Runtime.Assert(0 <= maxNew && maxNew < float.Epsilon);
		else Runtime.Assert(Math.Abs(maxOld/maxNew - 1) < 0.004f);

		let b = Self(a).Value;
		maxOld = Math.Max(a.x, a.y, a.z);
		maxNew = Math.Max(b.x, b.y, b.z);

		if (maxOld < FloatEpsilon)
			 Runtime.Assert(0 <= maxNew && maxNew < float.Epsilon);
		else Runtime.Assert(Math.Abs(maxOld/maxNew - 1) < float.Epsilon);
	}
}