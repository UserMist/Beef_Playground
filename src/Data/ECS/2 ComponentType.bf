using System;
namespace Playground;

public struct ComponentType: this(IComponent.Id id, Type type)
{
	public static Self Create<T>() where T: IComponent, struct {
		return Self(T.Id, typeof(T));
	}
}