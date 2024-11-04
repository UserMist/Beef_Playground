using System;
namespace Playground;

public interface IComponent
{
	public static Component.Type.Key TypeKey { get; };

	public interface Type
	{
		public Component.Type.Key TypeKey { get; }
		public System.Type Type { get; }
	}
}