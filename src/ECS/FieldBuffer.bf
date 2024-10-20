using System;
using System.Collections;
using System.Diagnostics;
namespace Playground_Lines;

///SoA for arbitrary data. Allows addition (up to a limit) and marking for removal (finished after refresh).
///TODO: Look into possibility of zero-tick actions due to timing of addition and removal
class FieldBuffer
{
	public Dictionary<String, FieldSpanInfo> FieldData;

	public int Count { get; private set; } = 0;
	private int count = 0;
	public int Capacity;
	
	private int stride;
	private int activeBufferSize;
	private uint8[] raw; //second half of array is a temporary buffer for deletions
	private List<int> removalQueue;

	public struct FieldSpanInfo: this(Type type, int offset, int length);
	
	public ~this() {
		delete raw;
		delete removalQueue;
		DeleteDictionaryAndKeys!(FieldData);
	}

	[AllowAppend]
	public this(int finalCapacity, params (Type type, StringView fieldName)[] fields) {
		this.stride = 0;
		for (let f in fields) {
			this.stride += f.type.Stride;
		}

		let v0 = new uint8[this.stride*finalCapacity*2];
		let v2 = new List<int>(finalCapacity);
		let v1 = new Dictionary<String, FieldSpanInfo>();

		this.raw = v0;
		this.FieldData = v1;
		this.removalQueue = v2;
		this.activeBufferSize = v0.Count/2;
		this.Capacity = finalCapacity;

		var offset = 0;
		for (let f in fields) {
			let len = finalCapacity * f.type.Stride;
			this.FieldData.Add(new .(f.fieldName), .(f.type, offset, len));
			offset += len;
		}
	}

	public bool HasField(String name) {
		return FieldData.ContainsKey(name);
	}

	public bool AddLater(params FieldValue[] values) {
		if (count < Capacity) {
			Set(count++, params values);
			return true;
		}
		return false;
	}

	public bool RemoveLater(int idx) {
		if (idx < count) {
			removalQueue.Add(idx);
			return true;
		}
		return false;
	}

	public Span<T> Span<T>(String name) {
		if (FieldData.TryGetValue(name, let info) && info.type == typeof(T)) {
			let ptr = (T*)(void*)((int)(void*)(raw.Ptr) + info.offset);
			return .(ptr, count);
		}
		Runtime.FatalError(scope $"Field \"{typeof(T).GetName(..scope .())} {name}\" is not present");
	}

	public void Set<T>(int idx, String name, T value) where T: struct {
		using (var v = Variant.Create(value)) {
			Runtime.Assert(idx < count && setAtIdx(idx, name, v), "Index is out of range");
		}
	}

	public void Set(int idx, params FieldValue[] values) {
		for (let value in values) {
			setAtIdx(idx, value.name, value.value);
		}
	}

	private bool setAtIdx(int idx, String name, Variant value) {
		let type = value.VariantType;
		if (FieldData.TryGetValue(name, let info)) {
			if (info.type == type) {
				let stride = type.Stride;
				let localOffset = idx*stride;
				let endPos = localOffset + stride;
				if (endPos <= info.length) {
					let toPtr = (void*)(info.offset + localOffset + (int)(void*)raw.Ptr);
					//doesn't need zeroing out, since we don't touch space between strides 
					Internal.MemSet(toPtr, 0, type.Stride);
					value.CopyValueData(toPtr);
					return true;
				}
				return false;
			}
			Runtime.FatalError(scope $"Field \"{name}\" requires type {type.GetName(..scope .())} instead of {info.type.GetName(..scope .())}");
		}
		Runtime.FatalError(scope $"Field \"{type.GetName(..scope .())}\" not found");
	}

	public void Refresh(bool removalQueueIsSorted = false) {
		executeRemovals(removalQueueIsSorted);
	}

	private void executeRemovals(bool queueIsSorted) {
		let deletedAmount = removalQueue.Count;
		if (deletedAmount == 0) {
			return;
		}

		if (!queueIsSorted) {
			removalQueue.Sort((a,b) => a <=> b);
		}

		raw.CopyTo(raw, 0, activeBufferSize, activeBufferSize);
		for (let info in FieldData.Values) {
			let stride = info.type.Stride;
			let iOffset = info.offset;
			let srcOffset = activeBufferSize + iOffset;

			var rawSize = 0;
			var i = 0;
			for (let j_ < deletedAmount) {
				let j = removalQueue[j_] * stride;

				let copyLength = j - i;
				raw.CopyTo(raw, srcOffset+i, iOffset+rawSize, copyLength);
				rawSize += copyLength;
				i = j + stride;
			}
			{
				let copyLength = count * stride - i;
				raw.CopyTo(raw, srcOffset+i, iOffset+rawSize, copyLength);
				rawSize += copyLength;
			}

			Internal.MemSet((.)(iOffset+rawSize + (int)(void*)raw.Ptr), 0, deletedAmount*stride);
		}
		count -= deletedAmount;
		Runtime.Assert(count >= 0, "Attempted to remove more records than there are present");
		removalQueue.Clear();
		Count = count;
	}
}

