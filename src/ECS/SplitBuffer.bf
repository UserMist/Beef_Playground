using System;
using System.Collections;
using System.Diagnostics;
namespace Playground_Lines;

///SoA for arbitrary data. Allows addition (up to a limit) and marking for removal (finished after refresh).
class SplitBuffer
{
	private uint8[] raw; //second half of array is a temporary buffer for deletions
	private Dictionary<String, fieldSpanInfo> fieldData;
	public int count = 0;
	public int capacity;
	private int recordArraySize;
	private List<int> removalQueue;

	const int defaultArraySize = 16384;
	const int removalQueueInitialCapacity = 32;

	private struct fieldSpanInfo: this(Type type, int offset, int length);
	
	public ~this() {
		delete raw;
		delete removalQueue;
		DeleteDictionaryAndKeys!(fieldData);
	}

	[AllowAppend]
	public this(params (Type type, StringView fieldName)[] fields) {
		let v0 = new uint8[defaultArraySize*2];
		let v2 = new List<int>(removalQueueInitialCapacity);
		let v1 = new Dictionary<String, fieldSpanInfo>();

		raw = v0;
		fieldData = v1;
		removalQueue = v2;
		recordArraySize = v0.Count/2;

		finishConstruction(fields);
	}

	[AllowAppend]
	public this(int arraySize, params (Type type, StringView fieldName)[] fields) {
		let v0 = new uint8[arraySize*2];
		let v2 = new List<int>(removalQueueInitialCapacity);
		let v1 = new Dictionary<String, fieldSpanInfo>();

		raw = v0;
		fieldData = v1;
		removalQueue = v2;
		recordArraySize = v0.Count/2;

		finishConstruction(fields);
	}

	private void finishConstruction((Type type, StringView fieldName)[] fields) {
		var recordStride = 0;
		for (let f in fields) {
			recordStride += f.type.Stride;
		}
		capacity = recordArraySize / recordStride;

		var offset = 0;
		for (let f in fields) {
			let len = capacity * f.type.Stride;
			fieldData.Add(new .(f.fieldName), .(f.type, offset, len));
			offset += len;
		}
	}

	public ref Variant this[String name, int idx] {
		set {
			Runtime.Assert(idx < count && setAtIdx(name, idx, value), "Index is out of range");
		}
		get {
			ThrowUnimplemented();
		}
	}

	public Span<T> Span<T>(String name) {
		if (fieldData.TryGetValue(name, let info) && info.type == typeof(T)) {
			let ptr = (T*)(void*)((int)(void*)(raw.Ptr) + info.offset);
			return .(ptr, count);
		}
		Runtime.FatalError(scope $"Field \"{typeof(T).GetName(..scope .())} {name}\" is not present");
	}

	public void Set<T>(String name, int idx, T value) where T: struct {
		using (var v = Variant.Create(value)) {
			Runtime.Assert(idx < count && setAtIdx(name, idx, v), "Index is out of range");
		}
	}

	private bool setAtIdx(String name, int idx, Variant value) {
		let type = value.VariantType;
		if (fieldData.TryGetValue(name, let info) && info.type == type) {
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
		Runtime.FatalError(scope $"Field \"{type.GetName(..scope .())} {name}\" is not present");
	}

	public bool HasField(String name) {
		return fieldData.ContainsKey(name);
	}
	
	public bool Add() {
		if (count < capacity) {
			count++;
			return true;
		}
		return false;
	}

	public bool MarkForRemoval(int idx) {
		if (idx < count) {
			removalQueue.Add(idx);
			return true;
		}
		return false;
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

		raw.CopyTo(raw, 0, recordArraySize, recordArraySize);
		for (let info in fieldData.Values) {
			let stride = info.type.Stride;
			let iOffset = info.offset;
			let srcOffset = recordArraySize + iOffset;

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
	}
}

