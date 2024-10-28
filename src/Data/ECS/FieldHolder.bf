using System;
namespace Playground;

struct FieldValue: this(String key, Variant value), IDisposable
{
	public static Self Create<T>(String key, T value) where T: struct {
		return .(key, Variant.Create(value));
	}

	public static Self Create<T>(String key, T value) where T: class {
		return .(key, Variant.Create(value));
	}

	public void Dispose() mut {
		value.Dispose();
	}
}