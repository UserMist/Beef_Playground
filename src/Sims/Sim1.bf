using System;
namespace Playground_Lines;

class Sim1: ISim
{
	public this() {

	}

	public ~this() {

	}

	float t;
	void ISim.OnFrame(float dt, Grid2<float3> image) {
		t += dt*4;
		image.Reset(default);
		image.DrawLine(.(-0.8f, Math.Cos(t)), .(0.8f, Math.Sin(t)), .(1f, 0.2f, 0.2f));
	}

	void ISim.OnTick(float dt) {

	}
}