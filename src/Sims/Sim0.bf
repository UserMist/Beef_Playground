using System;
using System.IO;
using System.Net;
using System.Threading;
using System.Collections;
using System.Diagnostics;
using Playground.Data;
using Playground.Data.Record;
using Playground.Data.Record.Components;
using static System.Math;

namespace Playground.Data.Record.Components
{
	[Component(9640)]
	public struct PlayerTag: this(int id), IComponent
	{
	}

	[Component(515145)]
	public struct GravEmitter: this(float v), IComponent
	{
	}

	[Component(555145)]
	public struct GravAbsorber: this(float v), IComponent
	{
	}

	[Component(598777)]
	public struct SelfDestruct: this(float t), IComponent
	{

	}

	
	[Component(55777)]
	public struct Shield: this(float r), IComponent
	{

	}

	[Component(4951)]
	public struct Bullet: this(), IComponent {}
}

namespace Playground;

class Sim0: ISim
{
	RecordDomain domain = new .() ~ delete _;

	Random rng = new .(7) ~ delete _;
	float rand() => .(rng.NextDouble(-1,1));
	float rand(Random rng, float min = -1, float max = 1) => .(rng.NextDouble(min,max));

	IDumper dumper = new RawDumper(typeof(float3)) ~ delete _;
	public NetWriter netWriter = new .(dumper) ~ delete _;
	public NetReader netReader = new .(dumper) ~ delete _;

	public this() {
		let n = 13;

		var avgP = float3(0,0);
		var avgV = float3(0,0);
		for (let i < n) {
			add(let vel);
			avgV += vel;
		}
		domain.Refresh();

		avgV /= n;
		avgP /= n;
		domain.For("ref Pos3f, ref Vel3f, ref OldPos3f").Run(scope (pos,vel,oldPos) => {
			pos -= avgP;
			oldPos -= avgP;
			vel -= avgV;
		});

		Console.WriteLine("Simulation is running");
	}

	public ~this() {
		Socket.Uninit();
	}

	private RecordId add(out float3 vel) {
		let pos = float3(rand(), rand(), rand() * 0.01f)*0.5f;
		vel = float3(rand(), rand(), rand() * 0.01f)*0.4f;
		return domain.Add((Pos3f)pos, (Vel3f)vel, (OldPos3f)pos, GravEmitter(1f), GravAbsorber(1f));
	}

	float t;
	void ISim.DrawFrame(float dt, Grid2<float3> image) {
		t+=dt;

		let cells = image.cells.Ptr;
		let c = image.cells.Count;
		for (let i < c) {
			cells[i] = Lerp(cells[i], .(0.05f,0.02f,0.03f), 0.54f);
		}

		let ratio = float(image.height)/image.width;

		domain.For("Pos3f, Vel3f, ref OldPos3f -PlayerTag").Run(scope (pos,vel,oldPos) => {
			image.DrawLine(pos*.(ratio,1), oldPos*.(ratio,1), .All(0.5f));
			oldPos = pos;
		});

		domain.For("Pos3f, Vel3f, ref OldPos3f, PlayerTag").Run(scope (pos,vel,oldPos,ply) => {
			let rng = scope Random(ply.id);
			image.DrawLine(pos*.(ratio,1), oldPos*.(ratio,1), .(rand(rng,0,1), rand(rng,0,1), rand(rng,0,1)));
			oldPos = pos;

			/*let r = 0.04f;
			for (let j < image.height) {
				for (let i < image.width) {
					let dp = image.ScrerecoClip(.(i, j)) - p[i0];
					let len2 = (dp.x*dp.x + dp.y*dp.y);

					if (len2 < r*r) {
						image[i, j] = .All(1 - Sqrt(len2)/r);
					}
				}
			}*/
		});

		
		domain.For("Shield, Pos3f").Run(scope (shield, pos) => {
			var i = 0;
			while (i < 16) {
				let m = 2f/16 * Math.PI_f;
				let p = pos + shield.r * float2(Math.Cos(i*m), Math.Sin(i*m));
				i++;
				let op = pos + shield.r * float2(Math.Cos(i*m), Math.Sin(i*m));
				image.DrawLine(p*float2(ratio,1), op*float2(ratio,1), float3(0.2f,0.1f,0.5f));
			}
		});
	}

	void ISim.Advance(float dt) {
		var dt;
		dt *= 0.125f;

		domain.Refresh();

		domain.For("Pos3f,ref Vel3f,OldPos3f +GravAbsorber").Run(scope (pos,vel,oldPos) => {
			vel *= Math.Exp(-0.1f*dt);
			domain.For("Pos3f,Vel3f,OldPos3f +GravEmitter").Run(scope [&](pos2,vel2,oldPos2) => {
				if (pos == pos2) return;
				let dp = (pos - pos2);
				let len = dp.x*dp.x + dp.y*dp.y + dp.z*dp.z;
				vel += dp/(len)*dt*-0.1f;
			});
		});

		CommonMutators.AdvanceMotion(domain, dt);
		CommonMutators.Lessen<Vel3f>(domain, dt, 2f);
		CommonMutators.Shift<Vel3f>(domain, dt, .(0.1f, 0.2f, 0.f));

		domain.For("ref Pos3f, ref Vel3f").Run(scope (pos,vel) => {
			vel.x -= 0.05f*dt;
			vel.z = 0;
			pos.z = 0;
			if (pos.x < -0.5f)
				vel.x = Abs(vel.x);
		});

		domain.For("RecordId, ref SelfDestruct").Run(scope (id, s) => {
			if ((s.t -= dt) <= 0)
				domain.Remove(id);
		});

		domain.For("Shield, Pos3f").Run(scope (shield, pos) => {
			domain.For("Pos3f, ref Vel3f").Run(scope (p,v) => {
				let dp = p - pos;
				if (len2(dp) < shield.r * shield.r) {
					v += dp * dt * 1000;
				}
			});
		});

		domain.For("ref Vel3f, SelfDestruct, RecordId +Bullet").Run(scope (v,s,id) => {
			v += float2(Math.Cos(s.t*600 + id.guid.GetHashCode()), Math.Sin(s.t*600 + id.guid.GetHashCode())) * dt * 40;
		});
	}

	float len2(float3 v) {
		return v.x*v.x + v.y*v.y + v.z*v.z;
	}

	float3 axis(SDL2.SDL.Scancode input, SDL2.SDL.Scancode w, SDL2.SDL.Scancode a, SDL2.SDL.Scancode s, SDL2.SDL.Scancode d) {
		var acc = float3(0,0);
		if (input == w) {
			acc += .(0, 1);
		} else if (input == s) {
			acc -= .(0, 1);
		} else if (input == a) {
			acc -= .(1, 0);
		} else if (input == d) {
			acc += .(1, 0);
		}
		return acc;
	}


	void ISim.Act(SDL2.SDL.KeyboardEvent event) {
		var did = 0;
		switch(event.keysym.scancode) {
		case .Pageup:
			domain.For("RecordId -PlayerTag").Run(scope [&](id) => {
				if (did++ > 0) return;
				Console.WriteLine(id.guid.[Friend]mA.ToString(..scope .()));
				domain.Change(id, .Set(PlayerTag(15)), .Set(Shield(0.1f)));
			});

		case .PageDown:
			domain.For("RecordId +PlayerTag").Run(scope [&](id) => {
				if (did++ > 0) return;
				Console.WriteLine(id.guid.[Friend]mA.ToString(..scope .()));
				domain.Change(id, .Remove<PlayerTag>());
			});

		case .Insert:
			add(?);
			Console.WriteLine(domain.Count);

		case .Delete:
			domain.For("RecordId").Run(scope [&](id) => {
				if (did++ > 0) return;
				domain.Remove(id);
			});

		case .L:
			var i = 0;
			domain.For("RecordId").Run(scope (id) => {
				Console.Write("   ");
				Console.WriteLine(id.guid.[Friend]mA);
			}, scope [&](table) => { Console.WriteLine(scope $"\ntable{i++}:"); return true; });
			Console.WriteLine();

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

		Random rnd = scope .();
		domain.For("ref Vel3f, Pos3f, PlayerTag").Run(scope (vel, pos, tag) => {
			var acc = float3(0,0);
			if (tag.id == 15) {
				acc += axis(event.keysym.scancode, .W, .A, .S, .D) * 0.5f;
			} else if (tag.id == 1) {
				acc += axis(event.keysym.scancode, .Up, .Left, .Down, .Right) * 0.5f;
			}
			vel += acc;
			if (acc != default) {
				domain.Add(pos, (Vel3f)(vel - acc*10), (OldPos3f)(float3)pos, SelfDestruct(0.03f+rnd.Next(10)*0.01f), Bullet());
			}
		});
	}
	
		/*
	{
		RecordTable ur = new .((typeof(float), "x"), (typeof(int), "y")); defer delete ur;
		let a = ur.AddLater(.Create("x", 0.515f), .Create("y", 515512));
		let b = ur.AddLater(.Create("x", 35f), .Create("y", 45));

		ur..RemoveLater(a)..Refresh();

		RecordStorage r = scope .();
		r.tables.Add(ur);

		r.For("float, "x", int, "y">(scope (x, y) => {
			Console.WriteLine(x);
			Console.WriteLine(y);
		}, scope (u) => u.HasFields("x") && u.MissesFields());

		*/
}