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