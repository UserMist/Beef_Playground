using System;
using System.Collections;
namespace Playground_Lines;

///Collection of records of same field composition. Each record holds a primary key (field name - "!SYS_KEY!") and a bunch of other fields.
class RecordArchetype
{
	const String VId = "!PRIMARY_KEY!";
	public List<SplitBuffer> chunks = new .() ~ delete _;
	const int maxVariadicLengthFor = 12;
	
	[OnCompile(.TypeInit), Comptime]
	private static void variadicFor() {
		String begin = "{";
		String end = "}";
		String code = new .(); defer delete code;

		for (let step < maxVariadicLengthFor*2) {
			if (step == 0) continue;
			
			let g = genFor(step % 2 == 1, step / 2);
			//String noshow = step == 0? "[NoShow]" : "";

			code += scope $"""

				public void For{g.genericArgs}(delegate void({g.delegateArgs}) method){g.constraints} {begin}
					for (let chunk in chunks) {begin}{g.spanInits}
						let c = chunk.count;
						for (let i < c)
							method({g.spanArgs});
					{end}
				{end}

			""";
		}

		Compiler.EmitTypeBody(typeof(Self), code);
	}

	private static (String genericArgs, String delegateArgs, String constraints, String spanInits, String spanArgs, String delegateGenericArgs) genFor(bool includeEntId, int otherCount) {
		String genericArgs = new .();
		String delegateArgs = new .();
		String constraints = new .();
		String spanInits = new .();
		String spanArgs = new .();
		String delegateGenericArgs = new .();

		if (includeEntId) {
			delegateArgs += scope $"in {nameof(KId)} entId";
			spanInits += scope $"\n\t\t\tlet entIds = chunk.Span<{nameof(KId)}>({nameof(VId)});";
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

		return (genericArgs, delegateArgs, constraints, spanInits, spanArgs, delegateGenericArgs);
	}

	public bool Require(params String[] fields) {
		let chunk = chunks[0];
		for (let f in fields) {
			if (!chunk.HasField(f))
				return false;
		}
		return true;
	}

	public bool Forbid(params String[] fields) {
		let chunk = chunks[0];
		for (let f in fields) {
			if (chunk.HasField(f))
				return false;
		}
		return true;
	}
}