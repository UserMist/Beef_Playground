using System;
using System.IO;
namespace Playground_Lines;

class Assets {
	public static void FinalizeRGB24(Span<float3> rgb, uint8[3]* dest) {
		var j = 0;
		for (let i < rgb.Length) {
			let p = float(1 / 2.2);
			dest[j][0] = uint8(255 * Math.Pow(Math.Clamp(rgb[i].x, 0, 1), p));
			dest[j][1] = uint8(255 * Math.Pow(Math.Clamp(rgb[i].y, 0, 1), p));
			dest[j][2] = uint8(255 * Math.Pow(Math.Clamp(rgb[i].z, 0, 1), p));
			j++;
		}
	}

	///TODO: it accepts bgr24 for some reason
	public static void SaveTga(FileStream file, Grid2<uint8[3]> rgb, bool fromBottom = false, bool fromRight = false) {
		uint8 alphaDepth = 0;
		uint8[18] header = default;
		header[2] = 2;
		header[12] = uint8(rgb.width);
		header[13] = uint8(rgb.width >> 8);
		header[14] = uint8(rgb.height);
		header[15] = uint8(rgb.height >> 8);
		header[16] = 24;
		header[17] = alphaDepth | (fromRight? 16:0) | (fromBottom? 0:32);
		file.Write(header);
		file.Write(StringView((.)rgb.cells.Ptr, 3*rgb.cells.Count));
	}
}