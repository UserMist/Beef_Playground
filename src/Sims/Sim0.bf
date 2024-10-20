using System;
using System.IO;
using System.Collections;
using static System.Math;
namespace Playground_Lines;

class Sim0: ISim
{
	List<float3> oldp = new .() ~ delete _;
	List<float3> p = new .() ~ delete _;
	List<float3> v = new .() ~ delete _;
	
	Random rng = new .(15) ~ delete _;
	float rand() => .(rng.NextDouble()*2-1);

	public this() {
		var avgV = float3(0,0);
		var avgP = float3(0,0);
		let n = 3;
		for (let i < n) {
			p.Add(.(rand(), rand(), rand() * 0.01f)*0.5f);
			v.Add(.(rand(), rand(), rand() * 0.01f)*0.4f);
			oldp.Add(p[i]);
			avgV += v[i];
		}

		avgV /= n;
		for (var _v in ref v) {
			_v -= avgV;
		}

		avgP /= n;
		for (var _p in ref p) {
			_p -= avgP;
		}
	}

	float t;
	void ISim.OnFrame(float dt, Grid2<float3> image) {
		t+=dt;
		for (var col in ref image.cells) {
			col *= 0.97f;
		}

		for (let i < p.Count) {
			image.DrawLine(p[i], oldp[i], v[i]*0.5f+.All(0.5f));
			oldp[i] = p[i];
		}

		image.DrawLine(p[0], p[1], .All(0.1f));
	}

	void ISim.OnTick(float dt) {
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
			p[i] += v[i] * dt; 
		}

		for (let i < p.Count) {
			v[i].x -= 0.05f*dt;
			if (p[i].x < -0.5f) {
				v[i].x = Abs(v[i].x);
			}
		}
	}
	
		/*
	{
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

		*/
}