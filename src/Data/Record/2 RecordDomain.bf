using System;
using System.Collections;
using System.Threading;
namespace Playground.Data.Record;

using Playground.Data.Record.Components; //required for codegen

/// Collection of records with varying component compositions. Each record at least has a RecordId component.
public class RecordDomain
{
	public int DefaultCapacityPerChunk = 256;
	public List<RecordTable> tables = new .() ~ DeleteContainerAndItems!(_);
	private Dictionary<Query, List<RecordTable>> queryCache = new .() ~ DeleteDictionaryAndValues!(_);
	bool invalidateQueryCache = false;

	public Dictionary<Component.Type.Key, IRecordList> lists = new .() ~ DeleteDictionaryAndValues!(_);


	public int Count {
		get {
			var c = 0;
			for (let table in tables) c += table.Count;
			return c;
		}
	}

	public void ForTables(delegate void(RecordTable) method) {
		for (let table in tables)
			method(table);
	}

	public void ForTables(delegate void(RecordTable) method, delegate bool(RecordTable) selector) {
		for (let records in tables)
			if (selector(records))
				method(records);
	}

	public RecordId Add(params Span<Component> components) {
		Component.Type[] rawTypes = scope .[components.Length+1];
		rawTypes[0] = RecordId.AsType;
		for (let i < components.Length)
			rawTypes[i + 1] = components[i];
		return reserveTable<Component.Type>(params rawTypes).Add(params components);
	}

	public bool Remove(RecordId id) {
		for (let table in tables) {
			if (table.Remove(id))
				return true;
		}
		return false;
	}

	public struct Change
	{
		public Component.Type.Key typeKey;
		public Component? component = null;

		public static Change Set<T>(T v) where T: IComponent, ValueType
			=> .() { typeKey = T.TypeKey, component = Component.Create<T>(v) };

		public static Change Remove<T>() where T: IComponent
			=> .() { typeKey = T.TypeKey };
	}

	public bool Change(RecordId id, params Span<Change> changes) {
		for (let table in tables) if (table.indexing.TryGetValue(id, let indexing)) {
			let chunk = table.[Friend]chunks[indexing.0];
			var components = new List<Component>(chunk.header.Count + changes.Length); defer delete components;
			
			for (let change in changes) if (change.component.HasValue) {
				components.Add(change.component.ValueOrDefault);
			}

			for (let desc in chunk.header.Values) {
				var remove = false;
				for (let j < changes.Length) if (desc.componentType.typeKey == changes[j].typeKey) {
					remove = true;
					break;
				}
				
				if (!remove)
					components.Add(chunk.Get(indexing.1, desc.componentType));
			}

			return transfer(id, table, components);
		}
		return false;
	}

	private bool transfer(RecordId id, RecordTable from, Span<Component> components) {
		let index = from.indexing[id];
		Runtime.Assert(!from.[Friend]chunks[index.0].[Friend]removalQueue.Contains(index.1), "Attempted to change components of absent record");

		let table2 = reserveTable<Component>(params components);
		if (!table2.Add(id, params components)) {
			return false;
		}
		from.Remove(id, disableDestructors: true); //todo
		return true;
	}
	
	private RecordTable reserveTable<T>(params Span<T> rawComponents) where T: IComponent.Type
		=> reserveTable<T>(DefaultCapacityPerChunk, params rawComponents);

	private RecordTable reserveTable<T>(int capacityPerChunk, params Span<T> rawComponents) where T: IComponent.Type {
		for (let table in tables) if (table.HasOnly<T>(params rawComponents)) {
			return table;
		}

		invalidateQueryCache = true;
		return tables.Add(..new RecordTable()..[Friend]init(DefaultCapacityPerChunk, rawComponents));
	}

	public void Refresh() {
		for (let table in tables)
			table.Refresh();

		if (invalidateQueryCache) {
			for (let cachedList in queryCache.Values)
				delete cachedList;
			
			queryCache.Clear();
			invalidateQueryCache = false;
		}
	}

	public struct JobHandle
	{
		public List<RecordTable.JobHandle> events = new .();
		public RecordDomain domain;

		public bool WaitFor(int waitMS = -1) {
			while (events.Count > 0) {
				events[0].WaitFor(waitMS);
				events.RemoveAt(0);
			}
			delete events;
			return true;
		}
	}
	
	private struct Query: IHashable
	{
		public List<Component.Type.Key> includes;
		public List<Component.Type.Key> excludes = null;
		public int64 hash;
		public int64 keysum = 0;

		public this(List<Component.Type.Key> inc, List<Component.Type.Key> exc) {
			includes = inc..Sort(scope (a,b) => a.value<=>b.value);
			if (exc != null)
				excludes = exc..Sort(scope (a,b) => a.value<=>b.value);
			for (let i in includes)
				keysum += i.value;
			hash = keysum;
			if (excludes == null)
				hash += int32.MaxValue;
			else for (let i in excludes)
				hash += i.value<<1;
		}

		public int GetHashCode()
			=> hash;

		public static bool operator ==(Query a, Query b) {
			if ((a.includes.Count != b.includes.Count) || (a.excludes == null) != (b.excludes == null)) {
				return false;
			}
			for (let i < a.includes.Count) if (a.includes[i] != b.includes[i]) {
				return false;
			}
			if (a.excludes != null) for (let i < a.excludes.Count) if (a.excludes[i] != b.excludes[i]) {
				return false;
			}
			return true;
		}

		public void StaticDispose() {
			delete includes;
			delete excludes;
		}
	}
	
	public QueryBuilder<S> For<S>(S s) where S:const String
		=> .(this);

	public struct QueryBuilder<S>: this(RecordDomain domain) where S: const String
	{

		[OnCompile(.TypeInit), Comptime]
		static void emit() {
			let s = S == null? "RecordId" : S;

			var excludeOtherTypeNames = false;
			var includedTypeNames = scope List<StringView>(), excludedTypeNames = scope List<StringView>();

			var filterIdx = s.IndexOfAny(scope char8[2]('+', '-'));
			var signature = s.Substring(0, filterIdx < 0? s.Length : filterIdx);
			var ordinalName = scope String();
			if (!s.IsEmpty) for (var typeName in signature.Split(',')) {
				typeName..Trim();
				let byRef = typeName.StartsWith("ref ");
				let typeNameNaked = byRef? typeName.Substring(4)..TrimStart() : typeName;

				if (typeNameNaked.EndsWith("Ordinal")) {
					Runtime.Assert(ordinalName.IsEmpty, "Only 1 ordinal component per record is allowed");
					ordinalName.Set(typeNameNaked);
				}
				includedTypeNames.Add(typeNameNaked);
			}

			var ordinalInFilter = false;
			while (filterIdx >= 0 && filterIdx < s.Length) {
				var filterEnd = s.IndexOfAny(scope char8[2]('+', '-'), filterIdx + 1);
				if (filterEnd < 0) filterEnd = s.Length;

				let item = s[filterIdx..<filterEnd]..Trim();
				if (item.StartsWith('+')) {
					if (item.EndsWith("Ordinal")) {
						Runtime.Assert(ordinalName.IsEmpty, "Only 1 ordinal component per record is allowed");
						ordinalName.Set(item);
						ordinalInFilter = true;
					}
					includedTypeNames.Add(item.Substring(1));
				} else if (item.StartsWith("-*")) {
					excludeOtherTypeNames = true;
				} else if (item.StartsWith('-')) {
					excludedTypeNames.Add(item.Substring(1));
				}

				filterIdx = filterEnd + 1;
			}

			signature..TrimEnd();
			let code = new String(); defer delete code;
			snippetQuerying(code, includedTypeNames, excludeOtherTypeNames? null : excludedTypeNames);
			if (ordinalName.IsEmpty) {
				code += "\n\t// Run //\n";
				snippetRun(code, signature, false);
				snippetRun(code, signature, true);
				code += "\n\t// Schedule //\n";
				snippetSchedule(code, signature, false);
				snippetSchedule(code, signature, true);
			} else {
				code += scope $"""
	
					// Run //
					
					public void Run(delegate void({signature}) method) {{
						if (domain.lists.TryGetValue({ordinalName}.TypeKey, let list))
							list.For("{signature}").Run(method);
					}}
	
					// Schedule //
					
					public JobHandle Schedule(delegate void({signature}) method, int concurrency = 8) {{
						let handle = JobHandle() {{ domain = domain }};
						if (domain.lists.TryGetValue({ordinalName}.TypeKey, let list))
							handle.events.Add(list.For("{signature}").Schedule(method, concurrency));
						return handle;
					}}
	
				""";
			}
			Compiler.EmitTypeBody(typeof(Self), code);
		}

		[Comptime]
		private static void snippetQuerying(String code, List<StringView> includedTypeNames, List<StringView> excludedTypeNames) {
			let incList = snippetNewQueryList(..scope String(), includedTypeNames);
			let excList = excludedTypeNames == null? scope $"null" : snippetNewQueryList(..scope String(), excludedTypeNames);
			let filter = scope String();
			if (excludedTypeNames == null) {
				filter.Set("table.HasOnly(params includes)");
			} else if (excludedTypeNames.Count == 0) {
				filter.Set("table.Includes(params includes)");
			} else {
				filter.Set("table.Includes(params includes) && table.Excludes(params excludes)");
			}
			code += scope $"""

				private static List<Component.Type.Key> includes = {incList};
				private static List<Component.Type.Key> excludes = {excList};
				private static Query query = .(includes, excludes) ~ _.StaticDispose();
				private List<{nameof(RecordTable)}> getTables() {{
					if (!domain.[Friend]queryCache.TryGetValue(query, var tables)) {{
						tables = new .();
						domain.[Friend]queryCache[query] = tables;
						for (let table in domain.tables) if ({filter}) tables.Add(table);
					}}
					return tables;
				}}

			""";
		}
		
		[Comptime]
		private static void snippetNewQueryList(String str, List<StringView> list) {
			str += "new List<Component.Type.Key>(){";
			for (let i in list) {
				if (@i.Index > 0) str += ", ";
				str += scope $"{i}.TypeKey";
			}
			str += "}";
		}

		[Comptime]
		private static void snippetRun(String code, StringView signature, bool useSelector) {
			let selectorArg  = !useSelector? "" : ", delegate bool(RecordTable table) selector";
			let selectorCond = !useSelector? "" : " if (selector(table))";
			code += scope $"""

				public void Run(delegate void({signature}) method{selectorArg}) {{
					let tables = getTables();
					for (let table in tables){selectorCond} table.For("{signature}").Run(method);
				}}

			""";
		}

		[Comptime]
		private static void snippetSchedule(String code, StringView signature, bool useSelector) {
			let selectorArg  = !useSelector? "" : ", delegate bool(RecordTable table) selector";
			let selectorCond = !useSelector? "" : " if (selector(table))";
			code += scope $"""

				public JobHandle Schedule(delegate void({signature}) method{selectorArg}, int concurrency = 8) {{
					let handle = JobHandle() {{ domain = domain }};
					let tables = getTables();
					for (let table in tables){selectorCond} handle.events.Add(table.For("{signature}").Schedule(method, concurrency));
					return handle;
				}}

			""";
		}
	}
}