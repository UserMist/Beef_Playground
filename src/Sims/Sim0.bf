using System;
using System.IO;
using System.Net;
using System.Threading;
using System.Collections;
using static System.Math;
namespace Playground;

class Sim0: ISim
{
	RecordTable particles = new .(80, (typeof(float3), "pos"), (typeof(float3), "oldPos"), (typeof(float3), "vel")) ~ delete _;
	RecordID main;

	Random rng = new .(7) ~ delete _;
	float rand() => .(rng.NextDouble()*2-1);

	IDumper dumper = new RawDumper(typeof(float3)) ~ delete _;
	public NetWriter netWriter = new .(dumper) ~ delete _;
	public NetReader netReader = new .(dumper) ~ delete _;

	public this() {
		let n = 3;
		for (let i < n) main = particles.AddLater();
		particles.Refresh();

		var avgV = float3(0,0);
		var avgP = float3(0,0);

		particles.For<float3,"pos",float3,"vel",float3,"oldPos">(scope [&](pos,vel,oldPos) => {
			pos = .(rand(), rand(), rand() * 0.01f)*0.5f;
			vel = .(rand(), rand(), rand() * 0.01f)*0.4f;
			oldPos = pos;
			avgV += vel;
		});

		avgV /= n;
		avgP /= n;
		particles.For<float3,"pos",float3,"vel",float3,"oldPos">(scope (pos,vel,oldPos) => {
			pos -= avgP;
			oldPos -= avgP;
			vel -= avgV;
		});

		Console.WriteLine("Simulation is running");
	}

	public ~this() {
		Socket.Uninit();
	}

	float t;
	void ISim.DrawFrame(float dt, Grid2<float3> image) {
		t+=dt;

		let cells = image.cells.Ptr;
		let c = image.cells.Count;
		for (let i < c) {
			cells[i] = Lerp(cells[i], .(0.05f,0.02f,0.03f), 0.04f);
		}

		particles.For<float3,"pos",float3,"vel",float3,"oldPos">(scope (pos,vel,oldPos) => {
			image.DrawLine(pos*.(float(image.height)/image.width,1), oldPos*.(float(image.height)/image.width,1), vel*0.5f+.All(0.5f));
			oldPos = pos;

			/*let r = 0.04f;
			for (let j < image.height) {
				for (let i < image.width) {
					let dp = image.ScreenToClip(.(i, j)) - p[i0];
					let len2 = (dp.x*dp.x + dp.y*dp.y);

					if (len2 < r*r) {
						image[i, j] = .All(1 - Sqrt(len2)/r);
					}
				}
			}*/
		});
	}

	void ISim.Advance(float dt) {
		particles.ForIds<float3,"pos",float3,"vel",float3,"oldPos">(scope (entId,pos,vel,oldPos) => {
			vel *= Math.Exp(-0.1f*dt);
			particles.ForIds<float3,"pos",float3,"vel",float3,"oldPos">(scope [&](entId2,pos2,vel2,oldPos2) => {
				if (entId == entId2) return;
				let dp = (pos - pos2);
				let len = dp.x*dp.x + dp.y*dp.y + dp.z*dp.z;
				//vel += dp/len*(0.1f-len)*dt*0.1f;  vel *= 0.999f;
				vel += dp/(len)*dt*-0.1f;
			});
		});

		particles.For<float3,"pos",float3,"vel">(scope (pos,vel) => {
			pos += vel* dt; 
		});

		particles.For<float3,"pos",float3,"vel">(scope (pos,vel) => {
			vel.x -= 0.05f*dt;
			if (pos.x < -0.5f) {
				vel.x = Abs(vel.x);
			}
		});
	}

	void ISim.Act(SDL2.SDL.KeyboardEvent event) {
		var acc = float3(0,0);
		let p = 0.5f;
		switch(event.keysym.scancode) {
		case .W, .Up: acc.y += p;
		case .S, .Down: acc.y -= p;
		case .D, .Right: acc.x += p;
		case .A, .Left: acc.x -= p;
		case .Home:
			Console.Write("\n>");
			let tokens = Console.ReadLine(..scope .()).Split(' ');
			StringView token0 = default;
			for (let token in tokens) {
				if (@token.Pos == 0) {
					token0 = token;
					continue;
				} else if (token0 == "connect") {
					var portStart = token.LastIndexOf(':');
					var port = 80;
					if (portStart < 0) {
						portStart = token.Length;
					} else {
						port = int.Parse(token.Substring(portStart+1));
					}
					netWriter.UseTarget(token.Substring(0..<portStart), port);
					return;
				} else if (token0 == "selfconnect") {
					netWriter.UseTarget("localhost", int.Parse(token));
					netReader.UsePort(int.Parse(token));
					netWriter.input.Add(new float3(5,4,3));
					return;
				}
			}

			if (token0 == "disconnect") {
				netWriter.UseTarget(null, null);
				return;
			} else if (token0 == "dehost") {
				netReader.UsePort(null);
				return;
			} else if (token0 == "") {
				return;
			}
			Console.WriteLine("Unknown command");
		default:
		}

		/*particles.ForIds<float3,"vel">((entId, vel) => {
			if (main != entId) return;

			vel += acc;
		});*/
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