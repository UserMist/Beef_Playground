using System;
using System.Collections;
using System.Threading;
namespace Playground.Data.Record;

using Playground.Data.Record.Components; //required for codegen

/// Collection of records with varying component compositions. Each record at least has a RecordId component.
public class RecordDomain
{
	public List<RecordTable> tables = new .() ~ DeleteContainerAndItems!(_);
	public Dictionary<Component.Type.Key, IRecordList> lists = new .() ~ DeleteDictionaryAndValues!(_);

	public int DefaultCapacityPerChunk = 256;

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
		rawTypes[0] = .Create<RecordId>();
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
		return tables.Add(..new RecordTable()..[Friend]init(DefaultCapacityPerChunk, rawComponents));
	}

	public void Refresh() {
		for (let table in tables)
			table.Refresh();
	}

	public struct JobHandle
	{
		public List<RecordTable.JobHandle> events = new .();
		public Object obj;

		public bool WaitFor(int waitMS = -1) {
			while (events.Count > 0) {
				events[0].WaitFor(waitMS);
				events.RemoveAt(0);
			}
			delete events;
			return true;
		}
	}
	
	public QueryBuilder<S> For<S>(S s) where S:const String
		=> .(this);

	public struct QueryBuilder<S>: this(RecordDomain domain) where S: const String
	{
		[OnCompile(.TypeInit), Comptime]
		static void emit() {
			var s = scope String();
			if (S == null) {
				s.Set("");
			} else {
				s.Set(S);
			}

			var typekeys = scope String();
			var signature = scope String();

			let items = s.Split(',');
			var ordinalName = scope String();
			for (var typeName in items) {
				if (s.IsEmpty) break;
				typeName..Trim();

				if (@typeName.Pos == 0) {
				} else {
					typekeys += ", ";
					signature += ", ";
				}

				if (typeName.EndsWith("Ordinal")) {
					Runtime.Assert(ordinalName.IsEmpty, "Only 1 ordinal component per record is allowed");
					ordinalName.Set(typeName);
				}

				let byRef = typeName.StartsWith("ref ");
				signature += typeName;

				if (byRef) { typekeys += scope $"{typeName.Substring(4)}.TypeKey"; }
				else { typekeys += scope $"{typeName}.TypeKey"; }
			}

			let begin = "{";
			let end = "}";

			let ordinalCode = scope $"""

				// Run //
				
				public void Run(delegate void({signature}) method) {begin}
					if (domain.lists.TryGetValue({ordinalName}.TypeKey, let list))
						list.For("{s}").Run(method);
				{end}

				// Schedule //
				
				public JobHandle Schedule(delegate void({signature}) method, int concurrency = 8) {begin}
					let handle = JobHandle();
					if (domain.lists.TryGetValue({ordinalName}.TypeKey, let list))
						handle.events.Add(list.For("{s}").Schedule(method, concurrency));
					return handle;
				{end}

			""";

			let code = scope $"""

				// Run //

				public void Run(delegate void({signature}) method) {begin}
					for (let table in domain.tables)
						if (table.Includes({typekeys}))
							table.For("{s}").Run(method);
				{end}

				public void Run(delegate void({signature}) method, delegate bool({nameof(RecordTable)} table) selector) {begin}
					for (let table in domain.tables)
						if (table.Includes({typekeys}) && selector(table))
							table.For("{s}").Run(method);
				{end}

				// Schedule //
			
				public JobHandle Schedule(delegate void({signature}) method, int concurrency = 8) {begin}
					let handle = JobHandle();
					for (let table in domain.tables)
						if (table.Includes({typekeys}))
							handle.events.Add(table.For("{s}").Schedule(method, concurrency));
					return handle;
				{end}

				public JobHandle Schedule(delegate void({signature}) method, delegate bool({nameof(RecordTable)} table) selector, int concurrency = 8) {begin}
					let handle = JobHandle();
					for (let table in domain.tables)
						if (table.Includes({typekeys}) && selector(table))
							handle.events.Add(table.For("{s}").Schedule(method, concurrency));
					return handle;
				{end}

			""";

			Compiler.EmitTypeBody(typeof(Self), ordinalName.IsEmpty? code : ordinalCode);
		}
	}
}