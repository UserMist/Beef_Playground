using System;
namespace Playground.Data;

public struct StridedSpan<T>
{
	public void* Ptr;
	public int Length;
	public int Stride;

	public this(T* ptr, int length, int extraStride = 0, int offset = 0) {
		this.Ptr = (void*)(offset + (int)(void*)ptr);
		this.Stride = typeof(T).Stride + extraStride;
		this.Length = length;
	}

	public ref T this[int idx] {
		[Unchecked, Inline] get
			=> ref *(T*)(void*)(idx*Stride + (int)Ptr);

		[Checked] get {
			Runtime.Assert((uint)idx < (uint)Length);
			return ref *(T*)(void*)(idx*Stride + (int)Ptr);
		}

		[Unchecked, Inline] set
			=> *(T*)(void*)(idx*Stride + (int)Ptr) = value;

		[Checked] set {
			Runtime.Assert((uint)idx < (uint)Length);
			*(T*)(void*)(idx*Stride + (int)Ptr) = value;
		}
	}
}