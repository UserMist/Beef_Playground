using System;
using System.Collections;
using System.Diagnostics;
namespace Playground.Data.Entity;

using Playground.Data.Entity.Components; //required for codegen

/// A subset of EntityDomain. All entities in it have same composition.
public class EntityTable: IEntityTable
{
	private List<EntitySplitList> chunks;
	public Dictionary<EntityId, (int, int)> indexing;
	public int CapacityPerChunk => chunks[0].Capacity;

	public bool UsesPlainSpans => true;
	public int ChunkCount => chunks.Count;
	public int EntityCountForChunk(int idx) => chunks[idx].Count;
	public (int, int)? LocateEntity(EntityId id) {
		if (indexing.TryGetValue(id, let value))
			return value;
	   return null;
	}
	
	public void GetComponentChunk(int idx, Component.Type.Key typekey, out void* ptr, out int stride) {
		let chunk = chunks[idx];
		let info = chunk.header[typekey];
		ptr = (void*)((int)(void*)(chunk.[Friend]raw.Ptr) + info.binarySpanStart);
		stride = info.componentType.type.Stride;
	}

	public void GetComponentTypes(List<Component.Type> types) {
		for (let typekey in chunks[0].header.Values)
			types.Add(typekey.componentType);
	}

	public ~this() {
		DeleteContainerAndItems!(chunks);
		delete indexing;
	}

	public this() { }
	
	public this(int capacityPerChunk, params Span<Component.Type> header) {
		Component.Type[] mHeader = scope .[header.Length + 1];
		mHeader[0] = .Create<EntityId>();
		for (let i < header.Length) {
			mHeader[i + 1] = header[i];
		}
		init<Component.Type>(capacityPerChunk, mHeader);
	}
	
	private void init<T>(int capacityPerChunk, Span<T> header) where T: IComponent.Type {
		chunks = new .(1)..Add(new EntitySplitList()..Init(capacityPerChunk, header));
		indexing = new .(32);
	}
	
	public void RefreshChunks() {
		for (let chunkIdx < chunks.Count) {
			let chunk = chunks[chunkIdx];

			var removalStart = int.MaxValue;
			let idSpan = chunk.Span<EntityId>();
			for (let k1 in chunk.[Friend]removalQueue) {
				Runtime.Assert(indexing.Remove(idSpan[k1.idx]));
				removalStart = Math.Min(removalStart, k1.idx);
			}

			chunk.Refresh();

			for (var i = removalStart; i < chunk.Count; i++) {
				let id = idSpan[i];
				indexing.Remove(id);
				indexing.Add(id, (id.indexer, i));
			}
		}
	}

	public bool DetailedRemove(EntityId id, bool destructive) {
		if (!indexing.TryGetValue(id, let k))
			return false;
		return chunks[k.0].Remove(k.1, destructive);
	}

	public EntityId Add(params Span<Component> components)
		=> DetailedAdd(components, true);

	static Random idGenerator = new .(0) ~ delete _;
	public EntityId DetailedAdd(Span<Component> components, bool dispose) {
		EntityId id = ?;
		while (indexing.ContainsKey(id = EntityId(0, idGenerator.NextU32())))
			continue;
		return add(..id, dispose, components);
	}

	/// For importing entity data only
	public bool DetailedAdd(EntityId id, Span<Component> components, bool dispose) {
		if (indexing.ContainsKey(id))
			return false;
		add(id, true, components);
		return true;
	}

	private void add(EntityId id, bool dispose, Span<Component> components) {
		Component[] realValues = populate(..scope Component[components.Length + 1], components, id);
		defer realValues[0].Dispose();
		defer { if (dispose) for (let i < realValues.Count-1) realValues[i+1].Dispose();}

		for (let chunk in chunks) {
			if (chunk.AddWithoutResize(params realValues)) {
				indexing.Add(id, (@chunk.Index, chunk.[Friend]count-1));
				return;
			}
		}

		let chunk = chunks.Add(..new EntitySplitList(chunks[0]));
		chunk.AddWithoutResize(params realValues);
		indexing.Add(id, (chunks.Count-1, chunk.[Friend]count-1));
		return;
	}

	private void populate(Span<Component> rawComponents, Span<Component> components, EntityId id) {
		rawComponents[0] = .Create(id);
		for (let i < components.Length)
			rawComponents[i + 1] = components[i];
	}

	public float CalculateDataDensity() {
		var total = 1f; //last chunk is always 100% dense
		for (let i < chunks.Count - 1) {
			let chunk = chunks[i];
			total += float(chunk.Count)/chunk.Capacity;
		}
		return 1f - total/chunks.Count;
	}

	public void OptimizeDataDensity() {
		ThrowUnimplemented();
	}
}