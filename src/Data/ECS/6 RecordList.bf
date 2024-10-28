using System;
using System.Collections;
using System.Diagnostics;
namespace Playground;

/// SoA list for Record. It's a high-performance data structure, which allows marking for addition and removal (finished after refresh).
public class RecordList
{
	public Dictionary<IComponent.Id, ComponentDescription> header;

	public int Count { get; private set; } = 0;
	private int count = 0;
	public int Capacity;
	
	private int stride;
	private int activeBufferSize;
	private uint8[] raw; //second half of array is a temporary buffer for deletions
	private List<int> removalQueue;

	public struct ComponentDescription: this(Type type, int offset, int length);
	
	public ~this() {
		delete raw;
		delete removalQueue;
		delete header;
	}

	[AllowAppend]
	public this(int capacity, params ComponentType[] header) {
		this.stride = 0;
		for (let f in header) {
			this.stride += f.type.Stride;
		}

		let v0 = new uint8[this.stride*capacity*2];
		let v2 = new List<int>(capacity);
		let v1 = new Dictionary<IComponent.Id, ComponentDescription>();

		this.raw = v0;
		this.header = v1;
		this.removalQueue = v2;
		this.activeBufferSize = v0.Count/2;
		this.Capacity = capacity;

		var offset = 0;
		for (let f in header) {
			let len = capacity * f.type.Stride;
			this.header.Add(f.id, .(f.type, offset, len));
			offset += len;
		}
	}

	public bool HasComponent<T>() where T: IComponent
		=> header.ContainsKey(T.Id);

	public bool HasComponents(params IComponent.Id[] header) {
		if (this.header.Count < header.Count) {
			return false;
		}
		for (let id in header) {
			if (!this.header.ContainsKey(id)) {
				return false;
			}
		}
		return true;
	}

	public bool MissesComponent<T>() where T: IComponent
		=> !header.ContainsKey(T.Id);

	public bool MissesComponents(params IComponent.Id[] header) {
		for (let id in header) {
			if (this.header.ContainsKey(id)) {
				return false;
			}
		}
		return true;
	}

	public bool MatchesComponents(params IComponent.Id[] header) {
		if (this.header.Count != header.Count) {
			return false;
		}
		for (let c in this.header) {
			var found = false;
			for (let c2 in header) {
				if (c2 == c.key) {
					found = true;
					break;
				}
			}
			if (!found)
				return false;
		}
		return true;
	}

	public bool MarkToAddWithoutResizing(params Component[] components) {
		if (count < Capacity) {
			Set(count++, params components);
			return true;
		}
		return false;
	}

	public bool MarkToRemove(int idx) {
		if (idx < count) {
			removalQueue.Add(idx);
			return true;
		}
		return false;
	}

	public Span<T> Span<T>() where T: IComponent {
		if (header.TryGetValue(T.Id, let info) && info.type == typeof(T)) {
			let ptr = (T*)(void*)((int)(void*)(raw.Ptr) + info.offset);
			return .(ptr, count);
		}
		Runtime.FatalError(scope $"Components \"{typeof(T).GetName(..scope .())}\" are not present");
	}

	public void Set(int idx, params Component[] components) {
		Runtime.Assert(idx < count, "Index is out of range");
		for (let component in components) {
			setAtIdx(idx, component);
		}
	}

	private void setAtIdx(int idx, Component component) {
		let type = component.value.VariantType;
		if (!header.TryGetValue(component.id, let info)) Runtime.FatalError(scope $"Component of id {component.id} not found");
		if (info.type != type) Runtime.FatalError(scope $"Component of id {component.id} requires type {type.GetName(..scope .())} instead of {info.type.GetName(..scope .())}");

		component.value.CopyValueData((void*)(info.offset + idx*type.Stride + (int)(void*)raw.Ptr));
	}

	public void Refresh(bool removalQueueIsSorted = false) {
		let deletedAmount = removalQueue.Count;
		if (deletedAmount == 0) {
			Count = count;
			return;
		}

		if (!removalQueueIsSorted) {
			removalQueue.Sort((a,b) => a <=> b);
		}

		raw.CopyTo(raw, 0, activeBufferSize, activeBufferSize);
		for (let info in header.Values) {
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

