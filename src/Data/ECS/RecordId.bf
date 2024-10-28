using System;
namespace Playground;

struct RecordID: this(Guid guid), IHashable
{
	public const String FieldKey = "";
	
	public int GetHashCode()
		=> guid.GetHashCode();

	public this() {
		guid = .Create();
	}
}