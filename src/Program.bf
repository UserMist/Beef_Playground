using System;
using System.IO;
using System.Collections;
using static System.Math;
namespace Playground_Lines;

struct Tracer {
	public float3? p;

	public void supply<T>(Grid2<T> img, float3 p2, T col) mut {
		if (p.HasValue)
			img.DrawLine(p.ValueOrDefault, p2, col);
		p = p2;
	}
}

class Program
{
	static Random rng;
	static float rand() {
		return .(rng.NextDouble()*2-1);
	}
	
	public static void Main() {
		let seed = 15;
		for (let i < 1) {
			rng = scope .(seed);
			genFrameCollage(i);
		}
	}

	public static void genFrameCollage(int frame) {
		let w = 1920/4;
		let h = 1080/4;
		let finalImg = scope Grid2<float3>(w*4,h*4); defer Assets.SaveTga(scope FileStream()..Open(scope $"E:/test_{frame}.tga", .OpenOrCreate, .Write), finalImg);
		for (let i < 4) for (let j < 4) {
			let img = genFrame(frame, i, ..new .(w, h));
			img.CopyTo(finalImg, .(finalImg.width*i/4, finalImg.height*j/4));
			delete img;
		}
	}

	public static void genFrame(int frame, int mainidx, Grid2<float3> img) {
		for (let j < img.height) for (let i < img.width) {
			let p = img.ScreenToClip(.(i,j));
			//img[i, j] = Math.Lerp(float3(0,0.004f,0.007f), float3(0,0,0), Math.Sqrt(p.x*p.x + p.y*p.y)*0.5f);
			img[i, j] *= 0.5f;
		}

		List<Tracer> tracers = scope .();
		List<float3> p = scope .();
		List<float3> v = scope .();

		List<List<(float3 pos, float3 vel)>> trajectories = new .(); defer {DeleteContainerAndItems!(trajectories);}

		for (let i < 3) {
			tracers.Add(.());
			p.Add(.(rand(), rand(), rand() * 0.01f)*0.5f);
			v.Add(.(rand(), rand(), rand() * 0.01f)*0.4f);
			trajectories.Add(new .());
		}

		const float dt = 0.01f;
		for (var t = 0f; t <= 10; t += dt) {
			for (let i < p.Count) {
				v[i] *= Math.Exp(-0.1f*dt);
				for (let j < p.Count) {
					if (i == j) continue;
					let dp = (p[i] - p[j]);
					let len = Math.Sqrt(dp.x*dp.x + dp.y*dp.y + dp.z*dp.z);
					v[i] += dp/(len*len)*dt*-0.1f;
				}
			}

			for (let i < p.Count) {
				trajectories[i].Add((p[i], v[i]));
				p[i] += v[i] * dt; 
			}
		}

		var frameMin = float3(float.PositiveInfinity, float.PositiveInfinity, 0);
		var frameMax = float3(float.NegativeInfinity, float.NegativeInfinity, 0);

		for (let traj in trajectories) for (let trajDot in traj) {
			if (trajDot.pos.x.IsNaN || trajDot.pos.y.IsNaN || trajDot.pos.z.IsNaN) continue;
			frameMin = Min(frameMin, trajDot.pos);
			frameMax = Max(frameMax, trajDot.pos);
		}

		int maxTrajLength = 0;
		for (let traj in trajectories) maxTrajLength = Max(maxTrajLength, traj.Count);

		const float m = 0.999f; //exp(-a*dt)
		for (let i < maxTrajLength) {
			img.Map((c) => c*m);

			for (let j < trajectories.Count) {
				if (i >= trajectories[j].Count) continue;
				let trajDot = trajectories[j][i];

				let bias = 0.1f;
				let ppos = remap(trajDot.pos, frameMin, frameMax, .(-1+bias, -1+bias, -0.001f), .(1-bias, 1-bias, +0.001f));
				tracers[j].supply(img, .((.)ppos.x, (.)ppos.y), (trajDot.vel + .(0.5f, 0.5f, 0))*1f);
			}
		}
		
		let cc = float3(0.25f,0.25f,0.25f);
		img.DrawLine(.(+1,-1), .(+1,+1), cc);
		img.DrawLine(.(-1,+1), .(+1,+1), cc);
		img.DrawLine(.(-1,-1), .(+1,-1), cc);
		img.DrawLine(.(-1,-1), .(-1,+1), cc);
	}
}