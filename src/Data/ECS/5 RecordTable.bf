using System;
using System.Collections;
namespace Playground;

/// A subset of RecordDomain. All records in it have same composition.
public class RecordTable
{
	const int for_maxVariadicLength = 12;
	
	private ComponentType[] header ~ delete _;
	private List<RecordList> chunks;
	private Dictionary<RecordId, (int, int)> indexing;

	public ~this() {
		DeleteContainerAndItems!(chunks);
		delete indexing;
	}

	public this(params ComponentType[] header) {
		initFields(header);
		chunks = new .(1)..Add(new .(64, params this.header));
		indexing = new .(32);
	}

	public this(int capacityPerChunk, params ComponentType[] header) {
		initFields(header);
		chunks = new .(1)..Add(new .(capacityPerChunk, params this.header));
		indexing = new .(32);
	}

	private void initFields(ComponentType[] header) {
		this.header = new .[header.Count+1];
		this.header[0] = .Create<RecordId>();
		header.CopyTo(this.header, 0, 1, header.Count);
	}

	public RecordId AddLater(params Component[] components) {
		let id = RecordId();
		Component[] realValues = populate(..scope Component[components.Count + 1], components, id);
		defer {for (var v in realValues) v.Dispose();}

		for (let chunk in chunks) {
			if (chunk.MarkToAddWithoutResizing(params realValues)) {
				indexing.Add(id, (@chunk.Index, chunk.[Friend]count-1));
				return id;
			}
		}

		let chunk = chunks.Add(..new .(chunks.Back.Capacity));
		chunk.MarkToAddWithoutResizing(params realValues);
		indexing.Add(id, (chunks.Count-1, chunk.[Friend]count-1));
		return id;
	}

	private void populate(Component[] realComponents, Component[] components, RecordId id) {
		realComponents[0] = .Create(id);
		components.CopyTo(realComponents, 0, 1, components.Count);
	}

	public bool RemoveLater(RecordId id) {
		if (indexing.TryGetValue(id, let k)) {
			chunks[k.0].MarkToRemove(k.1);
			return true;
		}
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

	public bool HasComponents(params IComponent.Id[] header)
		=> chunks[0].HasComponents(params header);

	public bool MissesFields(params IComponent.Id[] header)
		=> chunks[0].MissesComponents(params header);
	
	public bool MatchesComponents(params IComponent.Id[] header)
		=> chunks[0].MatchesComponents(params header);
	
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

				public void For{g.genericArgs}(delegate void({g.delegateArgs}) method){g.constraints} {begin}
					for (let chunk in chunks) {begin}{g.spanInits}
						let c = chunk.Count;
						for (let i < c)
							method({g.spanArgs});
					{end}
				{end}

			""";
		}

		Compiler.EmitTypeBody(typeof(Self), code);
	}

	private static (String genericArgs, String delegateArgs, String constraints, String spanInits, String spanArgs, String delegateGenericArgs)
	for_genStrings(bool includeRecId, int otherCount) {
		String genericArgs = new .();
		String delegateArgs = new .();
		String constraints = new .();
		String spanInits = new .();
		String spanArgs = new .();
		String delegateGenericArgs = new .();
		
		if (includeRecId) {
			delegateArgs += scope $"in RecordId recId";
			spanInits += scope $"\n\t\t\tlet recIds = chunk.Span<RecordId>();";
			spanArgs += "recIds[i]";
		}

		for (let n < otherCount) {
			if (n > 0) {
				genericArgs += ", ";
				delegateGenericArgs += ", ";
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
		}

		if (!genericArgs.IsEmpty) {
			genericArgs..Insert(0, '<')..Append('>');
			delegateGenericArgs..Insert(0, '<')..Append('>');
		}

		/*if (includeRecId) {
			genericArgs.Insert(0, "Ids");
			delegateGenericArgs.Insert(0, "Ids");
		}*/

		return (genericArgs, delegateArgs, constraints, spanInits, spanArgs, delegateGenericArgs);
	}
}