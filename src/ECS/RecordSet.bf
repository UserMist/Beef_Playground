using System;
using System.Collections;
namespace Playground_Lines;

typealias KId = int[8];

///Collection of records of various compositions. Each record holds a primary key (field name - "!SYS_KEY!") and a bunch of other fields.
class RecordSet {
	public List<RecordArchetype> uniforms = new .() ~ DeleteContainerAndItems!(_);

	public void ForUniformBuffer(delegate void(RecordArchetype) method) {
		for (let records in uniforms)
			method(records);
	}

	public void ForUniformBuffer(delegate void(RecordArchetype) method, delegate bool(RecordArchetype) selector) {
		for (let records in uniforms) {
			if (selector(records))
				method(records);
		}
	}

	[OnCompile(.TypeInit), Comptime]
	private static void variadicFor() {
		String begin = "{";
		String end = "}";
		String code = new .(); defer delete code;

		for (let step < RecordArchetype.[Friend]maxVariadicLengthFor*2) {
			if (step == 0) continue;

			let otherCount = step / 2;
			let g = RecordArchetype.[Friend]genFor(step % 2 == 1, otherCount);

			String requireds = scope .();
			for (let i < otherCount) {
				if (i > 0) requireds += ", ";
				requireds += scope $"const V{i}";
			}

			code += scope $"""

				public void For{g.genericArgs}(delegate void({g.delegateArgs}) method, delegate bool({nameof(RecordArchetype)} uniform) selector){g.constraints} {begin}
					for (let uniform in uniforms)
						if (selector(uniform))
							uniform.For{g.delegateGenericArgs}(method);
				{end}

			""";
		}

		Compiler.EmitTypeBody(typeof(Self), code);
	}
}