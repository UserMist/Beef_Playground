using System;
using System.Collections;
namespace Playground_Lines;

///Collection of records of various compositions. Each record holds a primary key (field name - "RECORD_ID") and a bunch of other fields.
class RecordStorage
{
	public List<RecordTable> tables = new .() ~ DeleteContainerAndItems!(_);

	public void ForUniformBuffer(delegate void(RecordTable) method) {
		for (let table in tables)
			method(table);
	}

	public void ForUniformBuffer(delegate void(RecordTable) method, delegate bool(RecordTable) selector) {
		for (let records in tables) {
			if (selector(records))
				method(records);
		}
	}

	[OnCompile(.TypeInit), Comptime]
	private static void for_variadic() {
		String begin = "{";
		String end = "}";
		String code = new .(); defer delete code;

		for (let step < RecordTable.[Friend]for_maxVariadicLength*2) {
			if (step == 0) continue;

			let otherCount = step / 2;
			let g = RecordTable.[Friend]for_genStrings(step % 2 == 1, otherCount);

			String requireds = scope .();
			for (let i < otherCount) {
				if (i > 0) requireds += ", ";
				requireds += scope $"const V{i}";
			}

			code += scope $"""

				public void For{g.genericArgs}(delegate void({g.delegateArgs}) method, delegate bool({nameof(RecordTable)} uniform) selector){g.constraints} {begin}
					for (let table in tables)
						if (selector(table))
							table.For{g.delegateGenericArgs}(method);
				{end}

			""";
		}

		Compiler.EmitTypeBody(typeof(Self), code);
	}
}