using System;
namespace Playground;

public struct Component: this(IComponent.Id id, Variant value), IDisposable
{
	public static Self Create<T>(T value) where T: IComponent, struct {
		return Self(T.Id, Variant.Create(value));
	}
	
	public void Dispose() mut {
		value.Dispose();
	}
}

