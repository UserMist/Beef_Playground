using System;
using System.IO;
using Playground.Data;
namespace Playground;

public class AssetTools
{
	const float p = 0.453125f;
	private static uint8 toGamma(float x) {
		return uint8(255*Math.Pow(x, p));
	}

	[Inline]
	private static uint8 toDirtyGamma(float x) {
		let xx = x*x;
		let xxx = xx*x;
		return uint8(421.862f*xxx-911.555f*xx+744.693f*x);
	}

	/// not recommended
	public static void FinalizeRGB24(Span<float3> rgb, uint8* dest) {
		let src = Span<float>((.)rgb.Ptr, rgb.Length*3);
		let c = src.Length;
		for (let i < c) {
			let p = src[i];
			dest[i] = toDirtyGamma(p < 0f? 0f: p > 1f? 1f : p);
		}
	}

	//todo: linear normalized RGB to sRGB (clamp gamut saturation and peak values to 1, all while preserving perceived saturation+hue. Refer to CIECAM02, LMS colorspace, wide-gamut colorspaces)
	public static void FinalizeRGB24(Span<RGB> src, uint8* dest, bool accurate) {
		let c = src.Length;
		if (accurate) for (let i < c) {
			let p = src[i].Value;
			dest[i*3 + 0] = toGamma(Math.Clamp(p.x, 0, 1));
			dest[i*3 + 1] = toGamma(Math.Clamp(p.y, 0, 1));
			dest[i*3 + 2] = toGamma(Math.Clamp(p.z, 0, 1));
		}
		else for (let i < c) {
			let p = src[i].Value;
			dest[i*3 + 0] = toDirtyGamma(Math.Clamp(p.x, 0, 1));
			dest[i*3 + 1] = toDirtyGamma(Math.Clamp(p.y, 0, 1));
			dest[i*3 + 2] = toDirtyGamma(Math.Clamp(p.z, 0, 1));
		}
	}

	///TODO: it accepts bgr24 for some reason
	public static void UploadImageTga(Stream stream, Grid2<uint8[3]> rgb, bool fromBottom = false, bool fromRight = false) {
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

	public static class Hdr
	{
		public static void Upload(Stream stream, Grid2<RGB> rgb) {
			let content = new $"""
				#?RADIANCE
				GAMMA=1
				EXPOSURE=1
				FORMAT=32-bit_rle_rgbe

				-Y {rgb.height} +X {rgb.width}

				""";
			let cells = rgb.cells;
			let c = cells.Count;
			content.Reserve(c + content.Length);

			uint8[][4] unpacked = new .[rgb.cells.Count]; defer delete unpacked;
			for (let i < c) {
				unpacked[i] = colorAsHdrItem(cells[i]);
			}
			for (let i < rgb.height) {
				pack(unpacked[rgb.width*i ..< rgb.width*(i+1)], content);
			}
			delete stream.Write(..content);
		}

		public static void Download(Stream stream, Grid2<RGB> rgb) {
			String content = new String(); defer delete content;
			stream.CopyTo(scope StringStream(content, .Reference));
			if (!content.StartsWith("#?RADIANCE")) { Console.WriteLine("Wrong format"); return; }
			let lines = content.Split('\n');
			var isRgbe = false;
			int2 size = default;
			var start = 0;
			for (let line in lines) {
				defer { start += line.Length + 1; }
				if (line.StartsWith('#')) continue;
				if (line.StartsWith("FORMAT=")) {
					isRgbe = line.EndsWith("32-bit_rle_rgbe");
				}
				if (line.StartsWith("-Y") || line.StartsWith("+Y")) {
					size.y = int.Parse(line.Substring(3 ..< line.IndexOf(' ', 3))).Value;
					size.x = int.Parse(line.Substring(line.IndexOf(' ', 3) + 4)).Value;
					rgb.EnsureSize(size.x, size.y);
					break;
				} else if (line.StartsWith("-X") || line.StartsWith("+X")) {
					ThrowUnimplemented();
				}
			}

			let unpacked = new uint8[size.x*size.y][4];
			var src = (uint8*)&content[start];
			var dest = unpacked.Ptr;
			for (let l < size.y) {
				unpack(.(dest, size.x), ref src);
				dest = &dest[size.x];
			}

			defer delete unpacked;
			let c = unpacked.Count;
			let cells = rgb.cells;
			for (let i < c)
				cells[i] = hdrItemAsColor(unpacked[i]);
		}

		private static RGB hdrItemAsColor(uint8[4] item) {
			var item;
			item[3] -= int(128);
			return *(RGB*)&item;
		}

		private static uint8[4] colorAsHdrItem(RGB col) {
			var ret = RGB(col);
			ret.[Friend]exponent += int8(128);
			return *(uint8[4]*)&ret;
		}
		
		const int MINRUN = 4;
		const int MINELEN = 8;
		const int MAXELEN = 0x7fff;

		static void pack(Span<uint8[4]> src, String dest) {
			if ((src.Length < MINELEN) | (src.Length > MAXELEN)) {
				dest.Append(StringView((char8*)&src[0], 4));
				return;
			}

			writeByte(2, dest);
			writeByte(2, dest);
			writeByte(.(src.Length>>8), dest);
			writeByte(.(src.Length), dest);

			for (let i < 4) {
				int cnt = 1;
			    for (var j = 0; j < src.Length; j += cnt) {
					int beg;
					for (beg = j; beg < src.Length; beg += cnt) {
					    for (cnt = 1; (cnt < 127) & (beg+cnt < src.Length) && src[beg+cnt][i] == src[beg][i]; cnt++) continue;

					    if (cnt >= MINRUN)
							break;
					}

					if ((beg-j > 1) & (beg-j < MINRUN)) {
					    var c2 = j+1;
					    while (src[c2++][i] == src[j][i]) if (c2 == beg) {
						    writeByte(.(128+beg-j), dest);
						    writeByte(src[j][i], dest);
						    j = beg;
						    break;
						}
					}

					while (j < beg) {
						let c2 = uint8(Math.Min(128, beg-j));
					    writeByte(c2, dest);
					    for (let ia < c2)
							writeByte(src[j++][i], dest);
					}

					if (cnt >= MINRUN) {
					    writeByte(.(128+cnt), dest);
					    writeByte(src[beg][i], dest);
					} else
					    cnt = 0;
			    }
			}
		}

		static void unpackOld(Span<uint8[4]> dest, ref uint8* src) {
			var lShift = 0;
			for (var destPos = 0; destPos < dest.Length;) {
				let srcItem = uint8[4](getByte(ref src), getByte(ref src), getByte(ref src), getByte(ref src));
				if ((srcItem[0] != 1) || (srcItem[1] != 1) || (srcItem[2] != 1)) {
					dest[destPos++] = srcItem;
					lShift = 0;
					continue;
				}

				let original = dest[destPos-1];
				let remains = (srcItem[3] << lShift) - 1;
				for (let i < remains)
					dest[destPos++] = original;
				lShift += 8;
			}
		}

		static void unpack(Span<uint8[4]> dest, ref uint8* src) {
			if ((dest.Length < MINELEN) | (dest.Length > MAXELEN)) {
				unpackOld(dest, ref src);
				return;
			}

			let red = getByte(ref src);
			if (red != 2) {
				src = &src[-1];
				unpackOld(dest, ref src);
				return;
			}

			dest[0][1] = getByte(ref src);
			dest[0][2] = getByte(ref src);
			let exp = getByte(ref src);

			if ((dest[0][1] != 2) | (dest[0][2] & 0x80 != 0)) {
				dest[0][0] = red;
				dest[0][3] = exp;
				unpackOld(dest.Slice(1), ref src);
				return;
			}

			for (let i < 4) for (var j = 0; j < dest.Length; ) {
				var count = getByte(ref src);
				if (count > 128) {
				    count &= 127;
					let original = getByte(ref src);
				    for (let k < count)
						dest[j++][i] = original;
				} else for (let k < count) {
					dest[j++][i] = getByte(ref src);
				}
			}
		}

		private static uint8 getByte(ref uint8* src) {
			defer { src = &src[1]; }
			return src[0];
		}

		private static void writeByte(uint8 byte, String dest) {
			dest.Append(char8(byte));
		}
	}
}