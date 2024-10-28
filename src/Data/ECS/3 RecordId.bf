using System;
namespace Playground;

public struct RecordId: this(Guid guid), IComponent, IHashable
{
	public static IComponent.Id Id => .(1);
	
	public int GetHashCode()
		=> guid.GetHashCode();

	public this() {
		guid = .Create();
	}
}