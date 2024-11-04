using System;
using System.IO;
namespace Playground;

class AssetTools
{
	const float p = 0.453125f;
	private static uint8 toGamma(float x) {
		return (.)Math.Pow(x, p);
	}

	[Inline]
	private static uint8 toDirtyGamma(float x) {
		let xx = x*x;
		let xxx = xx*x;
		return uint8(421.862*xxx-911.555f*xx+744.693f*x);
	}

	public static void FinalizeRGB24(Span<float3> rgb, uint8* dest) {
		let src = Span<float>((.)rgb.Ptr, rgb.Length*3);
		let c = src.Length;
		for (let i < c) {
			let p = src[i];
			dest[i] = toDirtyGamma(p < 0f? 0f: p > 1f? 1f : p);
		}
	}

	///TODO: it accepts bgr24 for some reason
	public static void StreamTga(Stream stream, Grid2<uint8[3]> rgb, bool fromBottom = false, bool fromRight = false) {
		uint8 alphaDepth = 0;
		uint8[18] header = default;
		header[2] = 2;
		header[12] = uint8(rgb.width);
		header[13] = uint8(rgb.width >> 8);
		header[14] = uint8(rgb.height);
		header[15] = uint8(rgb.height >> 8);
		header[16] = 24;
		header[17] = alphaDepth | (fromRight? 16:0) | (fromBottom? 0:32);
		stream.Write(header);
		stream.Write(StringView((.)rgb.cells.Ptr, 3*rgb.cells.Count));
	}
}