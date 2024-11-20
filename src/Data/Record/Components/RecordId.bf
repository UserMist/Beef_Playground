using System;
namespace Playground.Data.Record.Components;

[Component(1)]
public struct RecordId: this(Guid guid), IComponent, IHashable
{
	public this() {
		guid = .Create();
	}

	public int GetHashCode()
		=> guid.GetHashCode();
}