using System;
using System.Collections;
namespace Playground.Data.Record.Components;

[Component(30685)]
public struct Pos3f: float3, IComponent
{
	public this(float x, float y, float z = default): base(x, y, z) { }
	public static implicit operator Self(float3 v) => .(v.x, v.y, v.z);
}
	
[Component(30685)]
public struct Pos3: double3, IComponent
{
	public this(float x, float y, float z = default): base(x, y, z) { }
	public static implicit operator Self(float3 v) => .(v.x, v.y, v.z);
}
	
[Component(15143)]
public struct OldPos3f: float3, IComponent
{
	public this(float x, float y, float z = default): base(x, y, z) { }
	public static implicit operator Self(float3 v) => .(v.x, v.y, v.z);
}
	
[Component(59280)]
public struct Vel3f: float3, IComponent
{
	public this(float x, float y, float z = default): base(x, y, z) { }
	public static implicit operator Self(float3 v) => .(v.x, v.y, v.z);
}
	
[Component(14088)]
public struct RotVel3f: float3, IComponent
{
	public this(float x, float y, float z = default): base(x, y, z) { }
	public static implicit operator Self(float3 v) => .(v.x, v.y, v.z);
}
