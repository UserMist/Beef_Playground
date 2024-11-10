using System;
namespace Playground;

class RecordMutator
{
	public static void AdvanceMotion(RecordDomain domain, float dt) {
		domain.For<Pos3f, Vel3f>(scope (pos, vel) => {
			pos += vel*dt;
		}, false);
		Add(null, 5, Pos3f(0,0,0));
	}

	public static void Dampen<T>(RecordDomain domain, float dt, float strength) where T: IComponent, operator T*float {
		let d = Math.Exp(-dt*strength);
		domain.For<T>(scope (vel) => vel *= d, false);
	}

	public static void Add<T>(RecordDomain domain, float dt, T offset) where T: IComponent, var {
		let dp = offset*dt;
		domain.For<T>(scope (p) => p += dp, false);
	}
}