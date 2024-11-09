using System;
using System.Collections;
namespace Playground;

/// Collection of records with varying component compositions. Each record at least has a RecordId component.
public class RecordDomain
{
	public List<RecordTable> tables = new .() ~ DeleteContainerAndItems!(_);
	public int DefaultCapacityPerChunk = 64;

	public void ForTables(delegate void(RecordTable) method) {
		for (let table in tables)
			method(table);
	}

	public void ForTables(delegate void(RecordTable) method, delegate bool(RecordTable) selector) {
		for (let records in tables)
			if (selector(records))
				method(records);
	}

	public RecordId MarkToAdd(params Span<Component> components)
		=> reserveTable<Component>(params components).MarkToAdd(params components);

	public bool MarkToRemove(RecordId id) {
		for (let table in tables) {
			if (table.MarkToRemove(id))
				return true;
		}
		return false;
	}

	public bool MarkToUpdateComponents(RecordId id, params Span<Component> components) {
		for (let table in tables) if (table.indexing.TryGetValue(id, let indexing)) {
			let chunk = table.[Friend]chunks[indexing.0];
			var components2 = new List<Component>(chunk.header.Count + components.Length); defer delete components2;
				
			for (let i < components.Length) {
				var match = false;
				for (let desc in chunk.header.Values) {
					if (desc.componentType.typeKey == components[i].typeKey) {
						match = true;
						break;
					}
				}
				if (!match)
					components2.Add(components[i]);
			}

			System.Diagnostics.Debug.Assert(components2.Count > 0);
			for (let desc in chunk.header.Values) {
				components2.Add(chunk.Get(indexing.1, desc.componentType));
			}
			return transfer(id, table, components2);
		}
		return false;
	}

	public bool MarkToRemoveComponents(RecordId id, params Span<Component.Type> removals) {
		for (let table in tables) if (table.indexing.TryGetValue(id, let indexing)) {
			let chunk = table.[Friend]chunks[indexing.0];
			var components2 = new List<Component>(chunk.header.Count); defer delete components2;

			for (let desc in chunk.header.Values) {
				var removed = false;
				for (let j < removals.Length) {
					if (desc.componentType.typeKey == removals[j].typeKey) {
						removed = true;
						break;
					}
				}
				if (!removed)
					components2.Add(chunk.Get(indexing.1, desc.componentType));
			}
			return transfer(id, table, components2);
		}
		return false;
	}

	private bool transfer(RecordId id, RecordTable from, Span<Component> components) {
		let table2 = reserveTable<Component>(params components);
		if (!table2.MarkToAdd(id, params components)) {
			return false;
		}
		from.MarkToRemove(id, disableDestructors: true);
		return true;
	}
	
	private RecordTable reserveTable<T>(params Span<T> components) where T: IComponent.Type
		=> reserveTable<T>(DefaultCapacityPerChunk, params components);

	private RecordTable reserveTable<T>(int capacityPerChunk, params Span<T> components) where T: IComponent.Type {
		for (let table in tables) if (table.HasOnly<T>(params components)) {
			return table;
		}
		return tables.Add(..new RecordTable()..[Friend]init(DefaultCapacityPerChunk, components));
	}

	public void Refresh() {
		for (let table in tables)
			table.Refresh();
	}

	[OnCompile(.TypeInit), Comptime]
	private static void for_variadic() {
		let begin = "{";
		let end = "}";
		let code = new String(); defer delete code;

		for (let step < RecordTable.[Friend]for_maxVariadicLength*2) if (step > 0) {
			let g = RecordTable.[Friend]for_genStrings(step % 2 == 1, step / 2);
			code += scope $"""

				public void For{g.genericArgs}(delegate void({g.delegateArgs}) method, delegate bool({nameof(RecordTable)} table) selector, bool refresh = true){g.constraints} {begin}
					for (let table in tables)
						if ({g.includes}selector(table))
							table.For{g.delegateGenericArgs}(method, refresh);
				{end}

			""";
		}
		Compiler.EmitTypeBody(typeof(Self), code);
	}
}