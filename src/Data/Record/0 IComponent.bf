using System;
namespace Playground.Data.Record;

public interface IComponent
{
	public static Component.Type.Key TypeKey { get; };
	public static Component.Type AsType { get; }

	public interface Type
	{
		public Component.Type.Key TypeKey { get; }
		public System.Type Type { get; }
	}
}

//Forces record to be in a specific array-based table. Hence max 1 per record is allowed.
//Implementation name has to end in "Ordinal.
public interface IOrdinalComponent: IComponent
{
}

[Component(515675644)]
struct VertexOrdinal: int, IOrdinalComponent
{

}