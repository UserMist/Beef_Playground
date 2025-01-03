using System;
using System.Collections;
using System.Diagnostics;
namespace Playground.Data.Entity;

/// SoA list for Entity. It's a high-performance data structure, which allows marking for addition and removal (finished after refresh).
public class EntitySplitList
{
	public Dictionary<Component.Type.Key, ComponentDescription> header;
	private int count = 0;
	public int Capacity;
	private int stride;
	private int activeBufferSize;
	private uint8[] raw; //second half of array is a temporary buffer for deletions
	private List<(int idx, bool destroy)> removalQueue;
	private int64 headerSum;
	
	public int Count { get; private set; } = 0;

	public ~this() {
		delete raw;
		delete removalQueue;
		delete header;
	}
	
	public this() { }
	
	public this(int capacity, params Span<Component.Type> header) {
		Init(capacity, header);
	}

	public this(EntitySplitList template) {
		let header = scope Component.Type[template.header.Count];
		var i = 0;
		for (let c in template.header.Values) {
			header[i++] = c.componentType;
		}
		Init<Component.Type>(template.Capacity, header);
	}

	public void Init<T>(int capacity, Span<T> header) where T: IComponent.Type {
		//System.Span<ComponentType>(header).Sort((a, b) => a.typeKey.value <=> b.typeKey.value);
		this.stride = 0;
		this.headerSum = 0;
		for (let f in header) {
			this.stride += f.Type.Stride;
			headerSum += f.TypeKey.value;
		}

		let v0 = new uint8[this.stride*capacity*2];
		let v2 = new List<(int idx, bool destroy)>(capacity);
		let v1 = new Dictionary<Component.Type.Key, ComponentDescription>();

		this.raw = v0;
		this.header = v1;
		this.removalQueue = v2;
		this.activeBufferSize = v0.Count/2;
		this.Capacity = capacity;

		var offset = 0;
		for (let f in header) {
			let len = capacity * f.Type.Stride;
			this.header.Add(f.TypeKey, .(.(f.TypeKey, f.Destructor, f.Type), offset, len, f.Destructor));
			offset += len;
		}
	}

	public Span<T> Span<T>() where T: IComponent {
		if (header.TryGetValue(T.TypeKey, let info)) {
			let ptr = (T*)(void*)((int)(void*)(raw.Ptr) + info.binarySpanStart);
			return .(ptr, count);
		}
		Runtime.FatalError(scope $"Components \"{typeof(T).GetName(..scope .())}\" are not present");
	}

	public bool Includes<T>() where T: IComponent
		=> header.ContainsKey(T.TypeKey);

	public bool Includes<T>(params Span<T> header) where T: IComponent.Type
		=> Includes<T>(Component.Type.HeaderSum<T>(params header), params header);

	public bool Includes<T>(int headerSum, params Span<T> header) where T: IComponent.Type {
		if (this.header.Count < header.Length || this.headerSum < headerSum) {
			return false;
		}
		for (let id in header) if (!this.header.ContainsKey(id.TypeKey)) {
			return false;
		}
		return true;
	}

	public bool Excludes<T>() where T: IComponent
		=> !header.ContainsKey(T.TypeKey);

	public bool Excludes<T>(params Span<T> header) where T: IComponent.Type {
		for (let id in header) if (this.header.ContainsKey(id.TypeKey)) {
			return false;
		}
		return true;
	}
	
	public bool HasOnly<T>(params Span<T> header) where T: IComponent.Type
		=> HasOnly<T>(Component.Type.HeaderSum<T>(params header), params header);
	
	public bool HasOnly<T>(int64 headerSum, params Span<T> header) where T: IComponent.Type {
		if (this.header.Count != header.Length || this.headerSum != headerSum) {
			return false;
		}
		
		for (let c in this.header.Keys) {
			var found = false;
			for (let c2 in header) if (c2.TypeKey == c) {
				found = true;
				break;
			}
			if (found)
				return false;
		}
		return true;
	}

	public bool AddWithoutResize(params Span<Component> components) {
		if (count >= Capacity)
			return false;
		Set(count++, params components);
		return true;
	}

	public bool Remove(int idx, bool destructive) {
		if (idx >= count)
			return false;
		removalQueue.Add((idx, destructive));
		return true;
	}

	public Component Get<T>(int idx, T component) where T: IComponent.Type {
		if (header.TryGetValue(component.TypeKey, let info)) {
			let ptr = (void*)((int)(void*)(raw.Ptr) + info.binarySpanStart + idx*component.Type.Stride);
			return .(info.componentType.typeKey, T.Destructor, .Create(info.componentType.type, ptr));
		}
		Runtime.FatalError(scope $"Components \"{component.Type.GetName(..scope .())}\" are not present");
	}

	public void Set(int idx, params Span<Component> components) {
		Runtime.Assert(idx < count, "Index is out of range");
		for (let component in components) {
			setAtIdx(idx, component);
		}
	}

	private void setAtIdx(int idx, Component component) {
		let type = component.value.VariantType;
		if (!header.TryGetValue(component.typeKey, let info)) Runtime.FatalError(scope $"Component of id {component.typeKey} not found");
		if (info.componentType.type != type) Runtime.FatalError(scope $"Component of id {component.typeKey} requires type {type.GetName(..scope .())} instead of {info.componentType.type.GetName(..scope .())}");

		component.value.CopyValueData((void*)(info.binarySpanStart + idx*type.Stride + (int)(void*)raw.Ptr));
	}

	public void Refresh(bool removalQueueIsSorted = false) {
		defer { Count = count; }

		let queueLength = removalQueue.Count;
		if (queueLength == 0) {
			return;
		}

		if (!removalQueueIsSorted) {
			removalQueue.Sort((a,b) => a.idx <=> b.idx);
		}

		raw.CopyTo(raw, 0, activeBufferSize, activeBufferSize);
		for (let info in header.Values) {
			let destructor = info.destructor;
			let stride = info.componentType.type.Stride;
			let iOffset = info.binarySpanStart;
			let srcOffset = activeBufferSize + iOffset;

			if (destructor != null) for (let i < removalQueue.Count) if (removalQueue[i].destroy) {
				destructor(&raw[i*stride]);
			}

			var rawSize = 0;
			var i = 0;
			for (let j_ < queueLength) {
				let j = removalQueue[j_].idx * stride;

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

			Internal.MemSet((.)(iOffset+rawSize + (int)(void*)raw.Ptr), 0, queueLength*stride);
		}
		count -= queueLength;
		Runtime.Assert(count >= 0, "Attempted to remove more entities than there are present");
		removalQueue.Clear();
	}

	public struct ComponentDescription: this(Component.Type componentType, int binarySpanStart, int binarySpanLength, Component.Destructor destructor) { }
}

