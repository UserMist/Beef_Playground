using System;
using Playground.Data.Entity;
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

	public static void AdvanceMotion(EntityDomain domain, float dt) {
		domain.For("ref Pos3f, Vel3f").Run(scope (pos, vel)
			=> pos += vel*dt
		);
	}

	public static void Lessen<T>(EntityDomain domain, float dt, float strength) where T: IComponent, var {
		let d = Math.Exp(-dt*strength);
		Compiler.Mixin(scope $"{domainFor(typeof(T), true)}.Run(scope (vel) => vel *= d);");
	}

	public static void Shift<T>(EntityDomain domain, float dt, T offset) where T: IComponent, var {
		let dp = offset*dt;
		//Compiler.Mixin(scope $"{domainFor(typeof(T), true)}.Run(scope (p) => p += dp);");
	}
}