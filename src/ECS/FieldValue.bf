using System;
namespace Playground_Lines;

struct FieldValue: this(String name, Variant value)
{
	public static Self Create<T>(String name, T value) where T: struct {
		return .(name, Variant.Create(value));
	}

	public static Self Create<T>(String name, T value) where T: class {
		return .(name, Variant.Create(value));
	}
}