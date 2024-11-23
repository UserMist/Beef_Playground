using System;
using System.Collections;
using System.Threading;
using Playground.Data.Record.Components;
namespace Playground.Data.Record;

interface IRecordTable
{
	int RecordCountForChunk(int idx);
	int ChunkCount { get; }
	void GetComponentChunk(int idx, Component.Type.Key typekey, out void* ptr, out int stride);
	void GetComponentTypes(List<Component.Type> types);
	public (int, int) LocateRecord(RecordId id);

	void GetComponentTypekeys(List<Component.Type.Key> typekeys) {
		let types = GetComponentTypes(..scope .(typekeys.Count));
		for (let type in types)
			typekeys.Add(type.TypeKey);
	}

	int RecordCount {
		get {
			let cc = ChunkCount;
			var count = 0;
			for (let idx < cc)
				count += RecordCountForChunk(idx);
			return count;
		}
	}

	int ComponentCount => GetComponentTypekeys(..scope .()).Count;

	bool HasOnly(params Span<Component.Type.Key> a)
		=> a.Length == ComponentCount? Includes(params a) : false;

	bool Includes(params Span<Component.Type.Key> a) {
		if (a.Length < ComponentCount) {
			return false;
		}

		let my = (Span<Component.Type.Key>) GetComponentTypekeys(..scope .());
		if (Component.Type.HeaderSum(params a) > Component.Type.HeaderSum(params my)) {
			return false;
		}

		for (let bk in my) {
			var contains = false;
			for (let ak in a) if (ak.TypeKey == bk) {
				contains = true;
				break;
			}
			if (!contains)
				return false;
		}
		return true;
	}

	bool Excludes(params Span<Component.Type.Key> a) {
		let b = GetComponentTypekeys(..scope .());
		for (let ak in a) for (let bk in b) if (ak.TypeKey == bk) {
			return false;
		}
		return true;
	}

	public void RefreshChunks() { }
	
	RecordId DetailedAdd(Span<Component> values, bool dispose)
		=> ThrowUnimplemented();

	bool DetailedAdd(RecordId id, Span<Component> values, bool dispose)
		=> ThrowUnimplemented();

	bool DetailedRemove(RecordId id, bool destructive)
		=> ThrowUnimplemented();

	public bool UsesPlainSpans => false;

}

extension RecordTable
{
	public static Span<T> Span<T>(IRecordTable table, int idx) where T: IComponent {
		table.GetComponentChunk(idx, T.TypeKey, let ptr, ?);
		return .((.)ptr, table.RecordCountForChunk(idx));
	}

	public static StridedSpan<T> StridedSpan<T>(IRecordTable table, int idx) where T: IComponent {
		table.GetComponentChunk(idx, T.TypeKey, let ptr, let stride);
		return .((.)ptr, table.RecordCountForChunk(idx)) {
			Stride = stride
		};
	}

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

	public static QueryBuilder<S> For<S>(IRecordTable table, S s) where S:const String
		=> .(table);

	public struct QueryBuilder<S>: this(IRecordTable table) where S: const String
	{
		[OnCompile(.TypeInit), Comptime]
		static void emit() {
			let signature = S == null? "RecordId" : S;
			var typekeys = scope String();
			var args = scope String();
			var stridedSpanInits = scope String();
			var plainSpanInits = scope String();

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
				stridedSpanInits += scope $"\n\t\t\t\tlet span{idx} = RecordTable.StridedSpan<{typeNameNaked}>(table, chunkIdx);";
				plainSpanInits   += scope $"\n\t\t\t\tlet span{idx} = RecordTable.Span<{typeNameNaked}>(table, chunkIdx);";
			}
			
			let code = scope $"""

					// Run //
					
				public void Run(delegate void({signature}) method) {{
					let chunkCount = table.ChunkCount;
					if (table.UsesPlainSpans) {{ {snippetRun(plainSpanInits, args)}
					}} else {{ {snippetRun(stridedSpanInits, args)}
					}}
				}}
				
					// Schedule //

				public JobHandle Schedule(delegate void({signature}) method, int concurrency = 8) {{
					let handle = JobHandle();
					let chunkCount = table.ChunkCount;
					let totalC = table.RecordCount;
					let delta = totalC/concurrency;
					let remainder = totalC - delta*concurrency;

					var start = 0;
					var end = remainder + delta;
					if (table.UsesPlainSpans) {{ {snippetSchedule(plainSpanInits, args)}
					}} else {{ {snippetSchedule(stridedSpanInits, args)}
					}}
					return handle;
				}}
				""";

			

			Compiler.EmitTypeBody(typeof(Self), code);
		}

		private static String snippetRun(StringView spanInits, StringView args) {
			return new $"""

					for (let chunkIdx < chunkCount) {{
						let c = table.RecordCountForChunk(chunkIdx);{spanInits}
						for (let i < c)
							method({args});
					}}
			""";
		}

		private static String snippetSchedule(StringView spanInits, StringView args) {
			return new $"""
					
				for (let itemId < concurrency) {{
					let event = handle.events.Add(..new WaitEvent());
					ThreadPool.QueueUserWorkItem(new () => {{
						var lStart = start;
						var lEnd = end;
						for (let chunkIdx < chunkCount) {{
							let recordCount = table.RecordCountForChunk(chunkIdx);
							defer {{
								lStart -= recordCount;
								lEnd -= recordCount;
							}}
							if (lEnd <= 0) break;
							if (lStart >= recordCount) continue;
							let c0 = Math.Max(lStart, 0);
							let c1 = Math.Min(lEnd, recordCount);{spanInits}
							for (var i = c0; i < c1; i++)
								method({args});
						}}
						event.Set();
					}});
					start = end;
					end = start + delta;
				}}
		""";
		}
	}
}