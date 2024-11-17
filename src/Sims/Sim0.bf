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
}

namespace Playground;

class Sim0: ISim
{
	RecordDomain domain = new .() ~ delete _;

	Random rng = new .(7) ~ delete _;
	float rand() => .(rng.NextDouble()*2-1);
	float rand(Random rng, float min = -1, float max = 1) => .(rng.NextDouble()*(max-min)+min);

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
		return domain.Add((Pos3f)pos, (Vel3f)vel, (OldPos3f)pos);
	}

	float t;
	void ISim.DrawFrame(float dt, Grid2<float3> image) {
		t+=dt;

		let cells = image.cells.Ptr;
		let c = image.cells.Count;
		for (let i < c) {
			cells[i] = Lerp(cells[i], .(0.05f,0.02f,0.03f), 0.04f);
		}

		domain.For("Pos3f, Vel3f, ref OldPos3f").Run(scope (pos,vel,oldPos) => {
			image.DrawLine(pos*.(float(image.height)/image.width,1), oldPos*.(float(image.height)/image.width,1), .All(0.5f));
			oldPos = pos;
		}, scope (table) => table.Excludes(PlayerTag.TypeKey));

		domain.For("Pos3f, Vel3f, ref OldPos3f, PlayerTag").Run(scope (pos,vel,oldPos,ply) => {
			let rng = scope Random(ply.id);
			image.DrawLine(pos*.(float(image.height)/image.width,1), oldPos*.(float(image.height)/image.width,1), .(rand(rng,0,1), rand(rng,0,1), rand(rng,0,1)));
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
	}

	void ISim.Advance(float dt) {
		var dt;
		dt *= 0.125f;

		domain.For("RecordId,Pos3f,ref Vel3f,OldPos3f").Run(scope (recId,pos,vel,oldPos) => {
			vel *= Math.Exp(-0.1f*dt);
			domain.For("RecordId,Pos3f,Vel3f,OldPos3f").Run(scope [&](recId2,pos2,vel2,oldPos2) => {
				if (recId == recId2) return;
				let dp = (pos - pos2);
				let len = dp.x*dp.x + dp.y*dp.y + dp.z*dp.z;
				vel += dp/(len)*dt*-0.1f;
			});
		});

		CommonMutators.AdvanceMotion(domain, dt);
		CommonMutators.Dampen<Vel3f>(domain, dt, 0.5f);

		domain.For("Pos3f,ref Vel3f").Run(scope (pos,vel) => {
			vel.x -= 0.05f*dt;
			if (pos.x < -0.5f)
				vel.x = Abs(vel.x);
		});
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
			domain.For("RecordId").Run(scope [&](id) => {
				if (did++ > 0) return;
				Console.WriteLine(id.guid.[Friend]mA.ToString(..scope .()));
				domain.Change(id, .Set(PlayerTag(15)));
			}, scope (table) => table.Excludes(PlayerTag.TypeKey));

		case .PageDown:
			domain.For("RecordId").Run(scope [&](id) => {
				if (did++ > 0) return;
				domain.Change(id, .Remove<PlayerTag>());
			}, scope (table) => table.Includes(PlayerTag.TypeKey));

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

		domain.For("ref Vel3f, PlayerTag").Run(scope (vel, tag) => {
			if (tag.id == 15) {
				vel += axis(event.keysym.scancode, .W, .A, .S, .D) * 0.5f;
			} else if (tag.id == 1) {
				vel += axis(event.keysym.scancode, .Up, .Left, .Down, .Right) * 0.5f;
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