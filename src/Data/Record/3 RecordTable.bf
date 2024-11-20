using System;
using System.Collections;
using System.Threading;
namespace Playground.Data.Record;

using Playground.Data.Record.Components; //required for codegen

/// A subset of RecordDomain. All records in it have same composition.
public class RecordTable
{
	private List<RecordSplitList> chunks;
	public Dictionary<RecordId, (int, int)> indexing;
	public int CapacityPerChunk => chunks[0].Capacity;

	public int Count {
		get {
			var c = 0;
			for (let chunk in chunks) c += chunk.Count;
			return c;
		}
	}

	public ~this() {
		DeleteContainerAndItems!(chunks);
		delete indexing;
	}

	public this() { }
	
	public this(int capacityPerChunk, params Span<Component.Type> header) {
		Component.Type[] mHeader = scope .[header.Length + 1];
		mHeader[0] = .Create<RecordId>();
		for (let i < header.Length) {
			mHeader[i + 1] = header[i];
		}
		init<Component.Type>(capacityPerChunk, mHeader);
	}
	
	private void init<T>(int capacityPerChunk, Span<T> header) where T: IComponent.Type {
		chunks = new .(1)..Add(new RecordSplitList()..Init(capacityPerChunk, header));
		indexing = new .(32);
	}

	public bool SetRecord(RecordId id, params Span<Component> components) {
		if (indexing.TryGetValue(id, let v)) {
			chunks[v.0].Set(v.1, params components);
			return true;
		}
		return false;
	}

	public Component? GetComponent(RecordId id, IComponent.Type component) {
		if (indexing.TryGetValue(id, let v)) {
			return chunks[v.0].Get(v.1, component);
		}
		return null;
	}

	public RecordId Add(params Span<Component> components) {
		var id = RecordId();
		while (indexing.ContainsKey(id))
			id = RecordId();
		return add(..id, params components);
	}

	public bool Add(RecordId id, params Span<Component> components) {
		if (!indexing.ContainsKey(id)) {
			add(id, params components);
			return true;
		}
		return false;
	}

	private void add(RecordId id, params Span<Component> components) {
		Component[] realValues = populate(..scope Component[components.Length + 1], components, id);
		defer {for (var v in realValues) v.Dispose();}

		for (let chunk in chunks) {
			if (chunk.AddWithoutResize(params realValues)) {
				indexing.Add(id, (@chunk.Index, chunk.[Friend]count-1));
				return;
			}
		}

		let chunk = chunks.Add(..new RecordSplitList(chunks[0]));
		chunk.AddWithoutResize(params realValues);
		indexing.Add(id, (chunks.Count-1, chunk.[Friend]count-1));
		return;
	}

	private void populate(Span<Component> rawComponents, Span<Component> components, RecordId id) {
		rawComponents[0] = .Create(id);
		for (let i < components.Length)
			rawComponents[i + 1] = components[i];
	}

	public bool Remove(RecordId id, bool disableDestructors = false) {
		if (indexing.TryGetValue(id, let k)) {
			chunks[k.0].Remove(k.1);
			//indexing is deleted in refresh
			return true;
		}
		return false;
	}

	public bool MarkToRunDestructor(RecordId id, IComponent.Type component) {
		return false;
	}

	public void Refresh() {
		for (let chunkIdx < chunks.Count) {
			let chunk = chunks[chunkIdx];

			var removalStart = int.MaxValue;
			let idSpan = chunk.Span<RecordId>();
			for (let k1 in chunk.[Friend]removalQueue) {
				indexing.Remove(idSpan[k1]);
				removalStart = Math.Min(removalStart, k1);
			}

			chunk.Refresh();

			for (var i = removalStart; i < chunk.Count; i++) {
				let id = idSpan[i];
				indexing[id] = (indexing[id].0, i);
			}
		}
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

	[Inline]
	public bool Includes()
		=> true;

	[Inline]
	public bool Excludes()
		=> true;

	public bool Includes<T>(params Span<T> header) where T: IComponent.Type
		=> chunks[0].Includes<T>(params header);

	public bool Excludes<T>(params Span<T> header) where T: IComponent.Type
		=> chunks[0].Excludes<T>(params header);
	
	public bool HasOnly<T>(params Span<T> header) where T: IComponent.Type
		=> chunks[0].HasOnly<T>(params header);

	public struct JobHandle
	{
		public RecordTable table;
		public List<WaitEvent> events = new .();

		public bool WaitFor(int waitMS = -1) {
			while (events.Count > 0) {
				//if (!events[i].WaitFor(waitMS)) return false;
				delete events[0]..WaitFor(waitMS);
				events.RemoveAt(0);
			}
			delete events;
			return true;
		}
	}
	
	public QueryBuilder<S> For<S>(S s) where S:const String
		=> .(this);

	public struct QueryBuilder<S>: this(RecordTable table) where S: const String
	{
		[OnCompile(.TypeInit), Comptime]
		static void emit() {
			let signature = S == null? "RecordId" : S;
			var typekeys = scope String();
			var args = scope String();
			var spanInits = scope String();

			if (!signature.IsEmpty) for (var typeName in signature.Split(',')) {
				let idx = @typeName.Pos;
				typeName..Trim();
				let byRef = typeName.StartsWith("ref ");
				let typeNameNaked = byRef? typeName.Substring(4)..TrimStart() : typeName;

				if (idx > 0) {
					typekeys += ", ";
					args += ", ";
				}
				
				typekeys += scope $"{typeNameNaked}.TypeKey";
				args += scope $"{byRef? "ref " : ""}span{idx}[i]";
				spanInits += scope $"\n\t\t\tlet span{idx} = chunk.Span<{typeNameNaked}>();";
			}
			
			let code = scope $"""
	
					// Run //
					
					public void Run(delegate void({signature}) method) {{
						for (let chunkIdx < table.chunks.Count) {{
							let chunk = table.chunks[chunkIdx];{spanInits}
							let c = chunk.Count;
							for (let i < c)
								method({args});
						}}
					}}
	
					// Schedule //
	
					public JobHandle Schedule(delegate void({signature}) method, int concurrency = 8) {{
						let handle = JobHandle();
		
						var totalC = 0;
						for (let chunk in table.chunks)
							totalC += chunk.Count;
						let delta = totalC/concurrency;
						let remainder = totalC - delta*concurrency;
		
						var start = 0;
						var end = remainder + delta;
						for (let itemId < concurrency) {{
							let event = handle.events.Add(..new WaitEvent());
							ThreadPool.QueueUserWorkItem(new () => {{
								var lStart = start;
								var lEnd = end;
								for (let chunk in table.chunks) {{
									defer {{
										lStart -= chunk.Count;
										lEnd -= chunk.Count;
									}}
									if (lEnd <= 0) break;
									if (lStart >= chunk.Count) continue;
									let c0 = Math.Max(lStart, 0);
									let c1 = Math.Min(lEnd, chunk.Count);{spanInits}
									for (var i = c0; i < c1; i++) {{
										method({args});
									}}
								}}
								event.Set();
							}});
							start = end;
							end = start + delta;
					}}
					return handle;
				}}

			""";

			Compiler.EmitTypeBody(typeof(Self), code);
		}
	}
}