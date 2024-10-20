using System;
using System.IO;
using System.Collections;
using static System.Math;
namespace Playground_Lines;

//Philosophy:

//Struct constructors define values
//Class constructors only define how much data they need to allocate

class Program
{
	static Random rng;
	static float rand() {
		return .(rng.NextDouble()*2-1);
	}
	
	public static void Main() {
		RecordTable ur = new .((typeof(float), "x"), (typeof(int), "y")); defer delete ur;
		let a = ur.AddLater(.Create("x", 0.515f), .Create("y", 515512));
		let b = ur.AddLater(.Create("x", 35f), .Create("y", 45));

		ur..RemoveLater(a)..Refresh();

		RecordStorage r = scope .();
		r.tables.Add(ur);

		r.For<float, "x", int, "y">(scope (x, y) => {
			Console.WriteLine(x);
			Console.WriteLine(y);
		}, scope (u) => u.HasFields("x") && u.MissesFields());

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

		//List<Tracer> tracers = scope .();
		List<float3> p = scope .();
		List<float3> v = scope .();

		List<List<(float3 pos, float3 vel)>> trajectories = new .(); defer {DeleteContainerAndItems!(trajectories);}

		for (let i < 3) {
			//tracers.Add(.());
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

		var boxMin = float3(float.PositiveInfinity, float.PositiveInfinity, 0);
		var boxMax = float3(float.NegativeInfinity, float.NegativeInfinity, 0);

		for (let traj in trajectories) for (let trajDot in traj) {
			if (trajDot.pos.x.IsNaN || trajDot.pos.y.IsNaN || trajDot.pos.z.IsNaN) continue;
			boxMin = Min(boxMin, trajDot.pos);
			boxMax = Max(boxMax, trajDot.pos);
		}

		int maxTrajLength = 0;
		for (let traj in trajectories) maxTrajLength = Max(maxTrajLength, traj.Count);

		let sizes = (boxMax-boxMin) * 0.5f;
		let origin = (boxMax+boxMin) * 0.5f;
		let size = Max(sizes.x, sizes.y, sizes.z);
		let aspect = size*(float2(img.width/img.height, 1) - .All(0.1f));
		boxMin = origin - aspect;
		boxMax = origin - aspect;

		const float m = 0.999f; //exp(-a*dt)
		for (let i < maxTrajLength) {
			img.Map((c) => c*m);

			for (let j < trajectories.Count) {
				if (i >= trajectories[j].Count) continue;
				let trajDot = trajectories[j][i];

				let bias = 0.1f;
				let ppos = remap(trajDot.pos, boxMin, boxMax, .All(-1), .All(1));
				//tracers[j].supply(img, .((.)ppos.x, (.)ppos.y), (trajDot.vel + .(0.5f, 0.5f, 0))*1f);
			}
		}
		
		let cc = float3(0.25f,0.25f,0.25f);
		img.DrawLine(.(+1,-1), .(+1,+1), cc);
		img.DrawLine(.(-1,+1), .(+1,+1), cc);
		img.DrawLine(.(-1,-1), .(+1,-1), cc);
		img.DrawLine(.(-1,-1), .(-1,+1), cc);
	}
}