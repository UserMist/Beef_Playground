using System;
using System.Collections;
namespace Playground;

///Collection of records of same field composition. Each record holds a primary key (field name - "RECORD_ID") and a bunch of other fields.
class RecordTable
{
	const int for_maxVariadicLength = 12;

	private List<RecordList> chunks;
	private Dictionary<RecordID, (int, int)> indexing;
	private (Type type, StringView fieldName)[] fields ~ delete _;

	public ~this() {
		DeleteContainerAndItems!(chunks);
		delete indexing;
	}

	public this(params (Type type, StringView fieldName)[] fields) {
		initFields(fields);
		chunks = new .(1)..Add(new .(64, params this.fields));
		indexing = new .(32);
	}

	public this(int capacityPerChunk, params (Type type, StringView fieldName)[] fields) {
		initFields(fields);
		chunks = new .(1)..Add(new .(capacityPerChunk, params this.fields));
		indexing = new .(32);
	}

	private void initFields((Type type, StringView fieldName)[] fields) {
		this.fields = new .[fields.Count+1];
		this.fields[0] = (typeof(RecordID), RecordID.FieldKey);
		fields.CopyTo(this.fields, 0, 1, fields.Count);
	}

	public RecordID AddLater(params FieldValue[] values) {
		let id = RecordID();
		FieldValue[] realValues = populate(..scope FieldValue[values.Count + 1], values, id);
		defer {for (var v in realValues) v.Dispose();}

		for (let chunk in chunks) {
			if (chunk.AddLater(params realValues)) {
				indexing.Add(id, (@chunk.Index, chunk.[Friend]count-1));
				return id;
			}
		}

		let chunk = chunks.Add(..new .(chunks.Back.Capacity));
		chunk.AddLater(params realValues);
		indexing.Add(id, (chunks.Count-1, chunk.[Friend]count-1));
		return id;
	}

	private void populate(FieldValue[] realValues, FieldValue[] values, RecordID id) {
		realValues[0] = .Create(RecordID.FieldKey, id);
		values.CopyTo(realValues, 0, 1, values.Count);
	}

	public bool RemoveLater(RecordID id) {
		if (indexing.TryGetValue(id, let k)) {
			chunks[k.0].RemoveLater(k.1);
			return true;
		}
		return false;
	}

	public void Refresh() {
		for (let chunkIdx < chunks.Count) {
			let chunk = chunks[chunkIdx];

			let idSpan = chunk.Span<RecordID>(RecordID.FieldKey);
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

	public bool MatchStrictly(params String[] fields) {
		let chunk = chunks[0];

		if (chunk.FieldData.Count != fields.Count) {
			return false;
		}

		for (let f in chunk.FieldData) {
			var found = false;
			for (let f2 in fields) {
				if (f2 == f.key) {
					found = true;
					break;
				}
			}

			if (!found)
				return false;
		}
		return true;
	}

	public bool HasFields(params String[] fields) {
		let chunk = chunks[0];
		for (let f in fields) {
			if (!chunk.HasField(f))
				return false;
		}
		return true;
	}

	public bool MissesFields(params String[] fields) {
		let chunk = chunks[0];
		for (let f in fields) {
			if (chunk.HasField(f))
				return false;
		}
		return true;
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
	for_genStrings(bool includeEntId, int otherCount) {
		String genericArgs = new .();
		String delegateArgs = new .();
		String constraints = new .();
		String spanInits = new .();
		String spanArgs = new .();
		String delegateGenericArgs = new .();

		if (includeEntId) {
			delegateArgs += scope $"in {nameof(RecordID)} entId";
			spanInits += scope $"\n\t\t\tlet entIds = chunk.Span<{nameof(RecordID)}>(RecordID.FieldKey);";
			spanArgs += "entIds[i]";
		}

		for (let n < otherCount) {
			if (n > 0) {
				genericArgs += ", ";
				delegateGenericArgs += ", ";
			}
			if (n > 0 || includeEntId) {
				delegateArgs += ", ";
				spanArgs += ", ";
			}

			genericArgs += scope $"K{n},V{n}";
			delegateGenericArgs += scope $"K{n}, const V{n}";
			delegateArgs += scope $"ref K{n}";
			constraints += scope $"\n\twhere V{n}: const String";
			spanInits += scope $"\n\t\t\tlet span{n} = chunk.Span<K{n}>(V{n});";
			spanArgs += scope $"ref span{n}[i]";
		}

		if (!genericArgs.IsEmpty) {
			genericArgs..Insert(0, '<')..Append('>');
			delegateGenericArgs..Insert(0, '<')..Append('>');
		}

		if (includeEntId) {
			genericArgs.Insert(0, "Ids");
			delegateGenericArgs.Insert(0, "Ids");
		}

		return (genericArgs, delegateArgs, constraints, spanInits, spanArgs, delegateGenericArgs);
	}
}