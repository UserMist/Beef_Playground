using System;
using static System.Math;
namespace Playground;

class Sim1: ISim
{
	public this() {

	}

	public ~this() {

	}

	float t;
	void ISim.DrawFrame(float dt, Grid2<float3> image) {
		t += dt;
		let p = float2(Cos(t), Sin(t))*0.5f;
		image.DrawLine(p, p+.All(0.01f), .(1f, 0.2f, 0.2f));
	}

	void ISim.Advance(float dt) {

	}
}