using System;
using Playground.Data.Record;
namespace Playground;

class CommonMutators
{
	[Comptime]
	static String domainFor(Type t, bool byRef, String def = "Pos3f") {
		var name = t.GetName(..new .());
		if (name == "T")
			name = def;
		return new $"domain.For(\"{byRef? "ref " : ""}{name}\")";
	}

	public static void AdvanceMotion(RecordDomain domain, float dt) {
		domain.For("ref Pos3f, Vel3f").Run(scope (pos, vel) => pos += vel*dt);
	}

	public static void Lessen<T>(RecordDomain domain, float dt, float strength) where T: IComponent, var {
		let d = Math.Exp(-dt*strength);
		Compiler.Mixin(scope $"{domainFor(typeof(T), true)}.Run(scope (vel) => vel *= d);");
	}

	public static void Shift<T>(RecordDomain domain, float dt, T offset) where T: IComponent, var {
		let dp = offset*dt;
		//Compiler.Mixin(scope $"{domainFor(typeof(T), true)}.Run(scope (p) => p += dp);");
	}
}