using System;
namespace Playground.Data.Entity;

public interface IComponent
{
	public static Component.Type.Key TypeKey { get; };
	public static Component.Type AsType { get; }
	public static Component.Destructor Destructor => null;

	public interface Type
	{
		public Component.Type.Key TypeKey { get; }
		public System.Type Type { get; }
		public Component.Destructor Destructor { get; }
	}
}