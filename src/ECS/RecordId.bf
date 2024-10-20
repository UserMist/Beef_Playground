using System;
namespace Playground_Lines;

struct RecordId: this(Guid guid), IHashable
{
	public const String FieldKey = "RECORD_ID";
	
	public int GetHashCode()
		=> guid.GetHashCode();

	public this() {
		guid = .Create();
	}
}