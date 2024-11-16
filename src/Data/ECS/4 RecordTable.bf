using System;
using System.Collections;
using System.Threading;
namespace Playground;

/// A subset of RecordDomain. All records in it have same composition.
public class RecordTable
{
	const int for_maxVariadicLength = 12;
	
	private List<RecordSplitList> chunks;
	public Dictionary<RecordId, (int, int)> indexing;
	public int CapacityPerChunk => chunks[0].Capacity;

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
		}
		return false;
	}

	public Component? GetComponent(RecordId id, IComponent.Type component) {
		if (indexing.TryGetValue(id, let v)) {
			return chunks[v.0].Get(v.1, component);
		}
		return null;
	}

	public RecordId MarkToAdd(params Span<Component> components) {
		return markToAdd(..RecordId(), params components);
	}

	public bool MarkToAdd(RecordId id, params Span<Component> components) {
		if (!indexing.ContainsKey(id)) {
			markToAdd(id, params components);
			return true;
		}
		return false;
	}

	private void markToAdd(RecordId id, params Span<Component> components) {
		Component[] realValues = populate(..scope Component[components.Length + 1], components, id);
		defer {for (var v in realValues) v.Dispose();}

		for (let chunk in chunks) {
			if (chunk.MarkToAddWithoutResizing(params realValues)) {
				indexing.Add(id, (@chunk.Index, chunk.[Friend]count-1));
				return;
			}
		}

		let chunk = chunks.Add(..new RecordSplitList(chunks[0]));
		chunk.MarkToAddWithoutResizing(params realValues);
		indexing.Add(id, (chunks.Count-1, chunk.[Friend]count-1));
		return;
	}

	private void populate(Span<Component> rawComponents, Span<Component> components, RecordId id) {
		rawComponents[0] = .Create(id);
		for (let i < components.Length)
			rawComponents[i + 1] = components[i];
	}

	public bool MarkToRemove(RecordId id, bool disableDestructors = false) {
		if (indexing.TryGetValue(id, let k)) {
			chunks[k.0].MarkToRemove(k.1);
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

			let idSpan = chunk.Span<RecordId>();
			for (let k1 in chunk.[Friend]removalQueue) {
				indexing.Remove(idSpan[k1]);
			}
			chunk.Refresh();
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

	public bool Includes<T>(params Span<T> header) where T: IComponent.Type
		=> chunks[0].Includes<T>(params header);

	public bool Excludes<T>(params Span<T> header) where T: IComponent.Type
		=> chunks[0].Excludes<T>(params header);
	
	public bool HasOnly<T>(params Span<T> header) where T: IComponent.Type
		=> chunks[0].HasOnly<T>(params header);

	public struct JobHandle
	{
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

	[OnCompile(.TypeInit), Comptime]
	private static void for_variadic() {
		String begin = "{";
		String end = "}";
		String code = new .(); defer delete code;

		for (let step < for_maxVariadicLength*2) {
			if (step == 0) continue;
			
			let g = for_genStrings(step % 2 == 1, step / 2);
			//String noshow = step == 0? "[NoShow]" : "";

			code += scope $"""

				public void For{g.genericArgs}(delegate void({g.delegateArgs}) method, bool restructured = true){g.constraints} {begin}
					defer {begin} if (restructured) this.Refresh(); {end}
					for (let chunkIdx < this.chunks.Count) {begin}
						let chunk = this.chunks[chunkIdx];{g.spanInits}
						let c = chunk.Count;
						for (let i < c)
							method({g.spanArgs});
					{end}
				{end}

				public JobHandle ScheduleFor{g.genericArgs}(delegate void({g.delegateArgs}) method, int concurrency = 8, bool restructured = true){g.constraints} {begin}
					let handle = JobHandle();

					var totalC = 0;
					for (let chunk in this.chunks)
						totalC += chunk.Count;
					let delta = totalC/concurrency;
					let remainder = totalC - delta*concurrency;
		
					var start = 0;
					var end = remainder + delta;
					for (let itemId < concurrency) {begin}
						let event = handle.events.Add(..new WaitEvent());
						ThreadPool.QueueUserWorkItem(new () => {begin}
							var lStart = start;
							var lEnd = end;
							for (let chunk in this.chunks) {begin}
								defer {begin}
									lStart -= chunk.Count;
									lEnd -= chunk.Count;
								{end}
								if (lEnd <= 0) break;
								if (lStart >= chunk.Count) continue;
								let c = Math.Min(lEnd, chunk.Count);{g.spanInits}
								for (var i = lStart; i < c; i++)
									method({g.spanArgs});
							{end}
							event.Set();
						{end});
						start = end;
						end = start + delta;
					{end}
					return handle;
				{end}
			""";
		}

		Compiler.EmitTypeBody(typeof(Self), code);
	}

	private static (String genericArgs, String delegateArgs, String constraints, String spanInits, String spanArgs, String delegateGenericArgs, String includes)
	for_genStrings(bool includeRecId, int otherCount) {
		String genericArgs = new .();
		String delegateArgs = new .();
		String constraints = new .();
		String spanInits = new .();
		String spanArgs = new .();
		String delegateGenericArgs = new .();
		String includes = new .();
		
		if (includeRecId) {
			delegateArgs += scope $"in RecordId recId";
			spanInits += scope $"\n\t\t\tlet recIds = chunk.Span<RecordId>();";
			spanArgs += "recIds[i]";
		}

		if (otherCount > 0)
			includes += "table.Includes(";

		for (let n < otherCount) {
			if (n > 0) {
				genericArgs += ", ";
				delegateGenericArgs += ", ";
				includes += ", ";
			}

			if (n > 0 || includeRecId) {
				delegateArgs += ", ";
				spanArgs += ", ";
			}

			genericArgs += scope $"K{n}";
			delegateGenericArgs += scope $"K{n}";
			delegateArgs += scope $"ref K{n}";
			constraints += scope $"\n\twhere K{n}: IComponent";
			spanInits += scope $"\n\t\t\tlet span{n} = chunk.Span<K{n}>();";
			spanArgs += scope $"ref span{n}[i]";
			includes += scope $"K{n}.TypeKey";
		}

		if (otherCount > 0)
			includes += ") && ";

		if (!genericArgs.IsEmpty) {
			genericArgs..Insert(0, '<')..Append('>');
			delegateGenericArgs..Insert(0, '<')..Append('>');
		}

		/*if (includeRecId) {
			genericArgs.Insert(0, "Ids");
			delegateGenericArgs.Insert(0, "Ids");
		}*/

		return (genericArgs, delegateArgs, constraints, spanInits, spanArgs, delegateGenericArgs, includes);
	}
}