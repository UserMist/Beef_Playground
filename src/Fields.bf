using System;
using System.Collections;
namespace Playground;

public struct Pos3f: this(float3 v), IComponent
{
	public static IComponent.Id Id => .(30685);
}

public struct OldPos3f: this(float3 v), IComponent
{
	public static IComponent.Id Id => .(15143);
}

public struct Vel3f: this(float3 v), IComponent
{
	public static IComponent.Id Id => .(59280);
}