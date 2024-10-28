using System;
namespace Playground;

public interface IComponent
{
	public static Id Id { get; };

	public struct Id: this(uint16 value), IHashable
	{
		[Inline]
		public int GetHashCode()
			=> value.GetHashCode();
	}
}