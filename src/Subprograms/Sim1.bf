using System;
using static System.Math;
using Playground.Data;
using Playground.Data.Entity;
using Playground.Data.Entity.Components;
namespace Playground;

class Sim1: Subprogram
{
	float t;
	public override void UpdateIO(float dt, IOConnection io) {
		t += dt;
		io.Render(domain, scope (target) => {
			for (var p in ref target.image.cells) {
				p.Value *= 0.5f;
			}

			let p = float2(Cos(t), Sin(t))*0.5f;
			target.DrawLine(p, p+.All(0.01f), .(1f, 0.2f, 0.2f));
		});

		io.data.For("IOAxis").Run(scope (axis) => {
			if (axis.name != "+X" && axis.name != "+Y")
				return;

			domain.For("ref Vel3f (+Camera)").Run(scope (vel) => {
				if (axis.name == "+X")
					vel.x = (.)axis.value;
				else if(axis.name == "+Y")
					vel.y = (.)axis.value;
			});
		});
	}

	public override void Advance(float dt) {
		CommonMutators.AdvanceMotion(domain, dt);
	}
}