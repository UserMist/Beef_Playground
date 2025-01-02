using System;
using System.IO;
using Playground.Data;
using Playground.Data.Entity;
using Playground.Data.Entity.Components;

namespace Playground.Data.Entity.Components
{
	[Component(515515555)] public struct Draggable: this(float r), IComponent {}
	[Component(5155)] public struct Slider: this(float2 start, float2 end, int maxValue, int oldValue = 0), IComponent {
		public int value(float2 pos) {
			return .(Math.Round((maxValue)*(pos.x - start.x)/(end.x - start.x)));
		}
	}
}

namespace Playground;

class Sim2: Subprogram
{
	public this() {
		domain.Add(Slider(float2(-0.1f, 0), float2(0.1f, 0), 3), Pos2f(0.1f,0), Vel2f(0,0), Draggable(0.05f));
		domain.Refresh();
	}

	public ~this() {

	}

	bool heldL, heldR;
	EntityId? dragged;
	bool initimg;
	bool rerender;
	float strength = 1;

	float t;
	public override void UpdateIO(float dt, IOConnection io) {
		io.Render(domain, scope (target) => {
			if (!initimg) {
				initimg = true;
				target.image.EnsureSize(32*32, 32);
			}

			for (let g0 < 32) for (let b0 < 32) for (let r0 < 32) {
				let i = float3(Math.Pow(r0/31f, 2.2f), Math.Pow(1f-g0/31f, 2.2f), Math.Pow(b0/31f, 2.2f)); //incoming light as is
				let coefs = float3(i.y + i.z, i.x + i.z, i.x + i.y)*strength/16;

				var o = i;
				o += coefs;
				o *= 2;
				o = float3(Math.Pow(o.x, 1/2.2f), Math.Pow(o.y, 1/2.2f), Math.Pow(o.z, 1/2.2f));///float3(Math.Max(1,i.x), Math.Max(1,i.y), Math.Max(1,i.z)) * float3(r0/31f, 1f-g0/31f, b0/31f);
				o = float3(softClamp(o.x), softClamp(o.y), softClamp(o.z)) / softClamp(1);

				o = float3(Math.Clamp(o.x,0,1), Math.Clamp(o.y,0,1), Math.Clamp(o.z,0,1));
				target.image.cells[r0 + b0*32 + g0*32*32] = o;
			}

			//assume coords in gamma, mapping in linear-to-linear

			/*
			let holdR = Main.Instance.MouseR;
			if (!heldR && holdR) {
				AssetTools.Hdr.Upload(..scope FileStream()..Open("E:/screen.hdr", .OpenOrCreate, .Write), target.image);
				//AssetTools.Hdr.Download(..scope FileStream()..Open("E:/screen.hdr", .Open, .Read), image);
			} else if (!holdR) {
				/*image.Reserve(384, 216);
				for (let i < image.cells.Count) {
					image.cells[i] = .All(0);
				}
				for (let i < image.cells.Count) {
					var col = image.ScreenToClip(int2(i%image.width, i/image.width));
					image.cells[i] = col;
				}*/
			}
			heldR = holdR;

			let holdL = Main.Instance.MouseL;
			if (!heldL && holdL) {
				dragged = null;
				domain.For("EntityId, Draggable, Pos2f").Run(scope (ent, draggable, pos) => {
					let dp = Main.Instance.MousePos - pos;
					if (dp.x*dp.x + dp.y*dp.y > draggable.r*draggable.r) return;
					dragged = ent;
				});
			}
			if (!holdL) {
				dragged = null;
			}
			heldL = holdL;

			domain.For("Slider, Pos2f").Run(scope (slider,pos) => {
				target.image.DrawLine(slider.start, slider.end, float3(0.1f, 0.5f, 0.6f));
				target.image.DrawPoint(pos, float3.All(0));
				for (var r = 0f; r < 0.03f; r += 0.0002f) for (let i < 32) {
					target.image.DrawLine((pos+r*float2(Math.Cos(i*Math.PI_f/8f), Math.Sin(i*Math.PI_f/8f))), (pos+r*float2(Math.Cos((i+1)*Math.PI_f/8f), Math.Sin((i+1)*Math.PI_f/8f))), float3(0.1f,0.7f,0.8f)*i/32);
				}
			});
			*/
		});
	}

	float softClamp(float x) {
		return (2f / (1 + Math.Exp(-2*x)) - 1);
	}

	public override void Advance(float dt) {
		domain.For("Slider,ref Pos2f,Vel2f").Run(scope (slider,pos,vel) => {
			pos += dt*vel;
		});

		domain.For("EntityId, ref Vel2f, ref Pos2f").Run(scope (ent, vel, pos) => {
			if (ent != dragged) return;

			//vel = (Main.Instance.MousePos - pos) / dt;
		});

		domain.For("ref Slider,ref Pos2f,ref Vel2f").Run(scope (slider,pos,vel) => {
			if (pos.x <= slider.start.x) {
				pos.x = slider.start.x;
				vel.x = Math.Max(0, vel.x);
			} else if (pos.x >= slider.end.x) {
				pos.x = slider.end.x;
				vel.x = Math.Min(0, vel.x);
			}
			vel.y = 0;
			pos.y = slider.start.y;
			vel *= 0.7f;
			vel.x -= dt*4*Math.Sin((pos.x-slider.start.x)/(slider.end.x-slider.start.x)*2*Math.PI_f*slider.maxValue);

			if (slider.value(pos) != slider.oldValue) {
				rerender = true;
				strength = slider.value(pos) / float(slider.maxValue-1) * 1;
			}
			slider.oldValue = slider.value(pos);
		});
	}
}