using System;
namespace Playground.Data.Record.Components;

public struct RecordId: this(Guid guid), IComponent, IHashable
{
	public static Component.Type.Key TypeKey => .(1);

	public this() {
		guid = .Create();
	}

	public int GetHashCode()
		=> guid.GetHashCode();
}