namespace Playground;

interface ISim
{
	public void DrawFrame(float dt, Grid2<float3> image) {}
	public void Advance(float dt) {}
	public void Act(SDL2.SDL.KeyboardEvent event) {}
}