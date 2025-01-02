using System;
using System.Collections;
using System.Threading;
namespace Playground.Data.Entity;

using Playground.Data.Entity.Components; //required for codegen

/// Collection of entities with varying component compositions. Each entity at least has a EntityId component.
public class EntityDomain
{
	public int DefaultCapacityPerChunk = 256;
	public List<IEntityTable> tables = new .() ~ DeleteContainerAndItems!(_);
	private Dictionary<Query, List<IEntityTable>> queryCache = new .() ~ DeleteDictionaryAndValues!(_);
	bool invalidateQueryCache = false;

	public Dictionary<uint32, IEntityTable> sequences = new .() ~ DeleteDictionaryAndValues!(_);

	public int Count {
		get {
			var c = 0;
			for (let table in tables) c += table.EntityCount;
			return c;
		}
	}

	public void ForTables(delegate void(IEntityTable) method) {
		for (let table in tables)
			method(table);
	}

	public void ForTables(delegate void(IEntityTable) method, delegate bool(IEntityTable) selector) {
		for (let entities in tables)
			if (selector(entities))
				method(entities);
	}

	public EntityId Add(params Span<Component> components) {
		return reserveTable<Component>(0, DefaultCapacityPerChunk, components).DetailedAdd(components, true);
	}

	public EntityId Add(uint32 indexer, params Span<Component> components) {
		return reserveTable<Component>(indexer, DefaultCapacityPerChunk, components).DetailedAdd(components, true);
	}

	public bool Remove(EntityId id) {
		for (let table in tables) {
			if (table.DetailedRemove(id, true))
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

	public bool Change(EntityId id, params Span<Change> changes) {
		for (let table in tables) {
			let indexingRaw = table.LocateEntity(id);
			if (!indexingRaw.HasValue) { continue; }
			let indexing = indexingRaw.ValueOrDefault;

			let components = new List<Component>(changes.Length * 2); defer delete components;
			let header = table.GetComponentTypes(..scope .());

			for (let change in changes) if (change.component.HasValue) {
				components.Add(change.component.ValueOrDefault);
			}
	
			for (let type in header) {
				var remove = false;
				for (let j < changes.Length) if (type.TypeKey == changes[j].typeKey) {
					remove = true;
					break;
				}

				if (!remove) {
					table.GetComponentChunk(indexing.0, type.TypeKey, let ptr, let stride);
					let ptr2 = (uint8*) ptr;
					components.Add(.(type.typeKey, type.destructor, .Create(type.type, &ptr2[stride*indexing.1])));
				}
			}

			return transfer(id, table, components);
		}
		return false;
	}

	private bool transfer(EntityId id, IEntityTable from, Span<Component> components) {
		//let indexing = from.LocateEntity(id);
		//Runtime.Assert(!from.[Friend]chunks[indexing.0].[Friend]removalQueue.Contains(indexing.1), "Attempted to change components of absent entity");

		Runtime.Assert(id.indexer == 0);

		let table2 = reserveTable<Component>(id.indexer, DefaultCapacityPerChunk, components);
		if (table2 == from) {
			for (let component in components)
				component.value.CopyValueData(getPtrById(table2, id, component.typeKey));
			return true;
		}

		if (!table2.DetailedAdd(id, components, true)) {
			return false;
		}
		from.DetailedRemove(id, false);
		from.RefreshChunks();
		return true;
	}

	private void* getPtrById(IEntityTable table, EntityId id, Component.Type.Key typekey) {
		let indexing = table.LocateEntity(id).Value;
		table.GetComponentChunk(indexing.0, typekey, let ptr, let stride);
		return &((uint8*)ptr)[stride*indexing.1];
	}

	private IEntityTable reserveTable<T>(uint32 indexer, int capacityPerChunk, Span<T> components) where T: IComponent.Type {
		if (indexer == 0) {

			var insertId = true;
			for (let c in components) if (c.TypeKey == EntityId.TypeKey) {
				insertId = false;
				break;
			}

			let off = (insertId? 1 : 0);
			let types = scope Component.Type[components.Length + off];
			let typekeys = scope Component.Type.Key[components.Length + off];
			if (insertId) {
				types[0] = .Create<EntityId>();
				typekeys[0] = EntityId.TypeKey;
			}
			for (let i < components.Length) {
				types[i+off] = .Create(components[i]);
				typekeys[i+off] = components[i].TypeKey;
			}
			for (let table in tables) if (table.HasOnly(params typekeys)) {
				return table;
			}
			invalidateQueryCache = true;
			return tables.Add(..new EntityTable()..[Friend]init<Component.Type>(DefaultCapacityPerChunk, types));
		}

		Runtime.Assert(sequences.TryGetValue(indexer, let table));
		return table;
	}

	public void Refresh() {
		for (let table in tables)
			table.RefreshChunks();

		if (invalidateQueryCache) {
			for (let cachedList in queryCache.Values)
				delete cachedList;
			
			queryCache.Clear();
			invalidateQueryCache = false;
		}
	}

	public Result<T> GetComponent<T>(EntityId id) where T: IComponent {
		for (let table in tables) {
			if (!table.LocateEntity(id).HasValue) continue;
			return *(T*)getPtrById(table, id, T.TypeKey);
		}
		return .Err;
	}

	public struct JobHandle
	{
		public List<EntityTable.JobHandle> events = new .();
		public EntityDomain domain;

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
		public Component.Type.Key[] includes;
		public Component.Type.Key[] excludes = null;
		public int64 hash;
		public int64 keysum = 0;

		public this(Component.Type.Key[] inc, Component.Type.Key[] exc) {
			includes = Array.Sort(..inc, scope (a,b) => a.value<=>b.value);
			if (exc != null)
				excludes = Array.Sort(..exc, scope (a,b) => a.value<=>b.value);
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

	public struct QueryBuilder<S>: this(EntityDomain domain) where S: const String
	{

		[OnCompile(.TypeInit), Comptime]
		static void emit() {
			let s = S == null? "EntityId" : S;

			var excludeOtherTypeNames = false;
			var includedTypeNames = scope List<StringView>(), excludedTypeNames = scope List<StringView>();

			let filterStart = s.IndexOf('(');
			var signature = s.Substring(0, filterStart < 0? s.Length : filterStart);
			var ordinalName = scope String();
			for (var typeName in signature.Split(',')) if (!typeName..Trim().IsEmpty) {
				let byRef = typeName.StartsWith("ref ");
				let typeNameNaked = byRef? typeName.Substring(4)..TrimStart() : typeName;

				if (typeNameNaked.EndsWith("Ordinal")) {
					Runtime.Assert(ordinalName.IsEmpty, "Only 1 ordinal component per entity is allowed");
					ordinalName.Set(typeNameNaked);
				}
				includedTypeNames.Add(typeNameNaked);
			}

			var ordinalInFilter = false;
			if (filterStart >= 0) for (var i = filterStart + 1; i < s.Length; i++) {
				let i0 = i+1;
				if (s[i] == '+') {
					while (s[++i] != ' ' && s[i] != ')') continue;
					let item = includedTypeNames.Add(..s[i0..<i]);
					if (item.EndsWith("Ordinal")) {
						Runtime.Assert(ordinalName.IsEmpty, "Only 1 ordinal component per entity is allowed");
						ordinalName.Set(item);
						ordinalInFilter = true;
					}
				} else if (s[i] == '-' && s[i+1] == '*') {
					excludeOtherTypeNames = true;
				} else if (s[i] == '-') {
					while (s[++i] != ' ' && s[i] != ')') continue;
					excludedTypeNames.Add(s[i0..<i]);
				}
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
			let incArray = snippetNewQueryArray(..scope String(), includedTypeNames);
			let excArray = excludedTypeNames == null? scope $"null" : snippetNewQueryArray(..scope String(), excludedTypeNames);
			let filter = scope String();
			if (excludedTypeNames == null) {
				filter.Set("table.HasOnly<Component.Type.Key>(params includes)");
			} else if (excludedTypeNames.Count == 0) {
				filter.Set("table.Includes(params includes)");
			} else {
				filter.Set("table.Includes(params includes) && table.Excludes(params excludes)");
			}
			code += scope $"""

				private static Component.Type.Key[] includes = {incArray};
				private static Component.Type.Key[] excludes = {excArray};
				private static Query query = .(includes, excludes) ~ _.StaticDispose();

			""";
			snippetDefGetTables(code, filter);
		}

		private static void snippetDefGetTables(String code, StringView filter) {
			code += scope $"""

				private List<IEntityTable> getTables() {{
					if (!domain.[Friend]queryCache.TryGetValue(query, var tables)) {{
						tables = new List<IEntityTable>();
						domain.[Friend]queryCache[query] = tables;
						for (let table in domain.tables) if ({filter}) tables.Add(table);
					}}
					return tables;
				}}

			""";
		}
		
		[Comptime]
		private static void snippetNewQueryArray(String str, List<StringView> list) {
			str += scope $"new Component.Type.Key[{list.Count}](";
			for (let i in list) {
				if (@i.Index > 0) str += ", ";
				str += scope $"{i}.TypeKey";
			}
			str += ")";
		}

		[Comptime]
		private static void snippetRun(String code, StringView signature, bool useSelector) {
			let selectorArg  = !useSelector? "" : ", delegate bool(IEntityTable table) selector";
			let selectorCond = !useSelector? "" : " if (selector(table))";
			code += scope $"""

				public void Run(delegate void({signature}) method{selectorArg}) {{
					let tables = getTables();
					for (let table in tables){selectorCond} EntityTable.For(table, "{signature}").Run(method);
				}}

			""";
		}

		[Comptime]
		private static void snippetSchedule(String code, StringView signature, bool useSelector) {
			let selectorArg  = !useSelector? "" : ", delegate bool(IEntityTable table) selector";
			let selectorCond = !useSelector? "" : " if (selector(table))";
			code += scope $"""

				public JobHandle Schedule(delegate void({signature}) method{selectorArg}, int concurrency = 8) {{
					let handle = JobHandle() {{ domain = domain }};
					let tables = getTables();
					for (let table in tables){selectorCond} handle.events.Add(EntityTable.For(table, "{signature}").Schedule(method, concurrency));
					return handle;
				}}

			""";
		}
	}
}