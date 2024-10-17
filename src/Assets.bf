using System;
using System.IO;
namespace Playground_Lines;

class Assets {
	public static void SaveTga(FileStream file, Grid2<float3> rgb, uint8 bitDepth = 24, bool fromBottom = false, bool fromRight = false) {
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
				let p = float(1 / 2.2);
				let r = uint8(255 * Math.Pow(Math.Clamp(rgb.raw[i].x, 0, 1), p));
				let g = uint8(255 * Math.Pow(Math.Clamp(rgb.raw[i].y, 0, 1), p));
				let b = uint8(255 * Math.Pow(Math.Clamp(rgb.raw[i].z, 0, 1), p));
				str[j++] = char8(b);
				str[j++] = char8(g);
				str[j++] = char8(r);
			}
			file.Write(str);
		default: ThrowUnimplemented();
		}
	}
}