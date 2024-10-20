namespace Playground_Lines;

interface ISim
{
	public void OnFrame(float dt, Grid2<float3> image) {}
	public void OnTick(float dt) {}
}