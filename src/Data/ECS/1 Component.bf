using System;
namespace Playground;

public struct Component: this(Component.Type.Key typeKey, Variant value), IDisposable, IComponent.Type
{
	public Component.Type.Key TypeKey => this.typeKey;
	public System.Type Type => this.value.VariantType;

	public void Dispose() mut
		=> value.Dispose();
	
	public static Self Create<T>(T value) where T: IComponent, struct
		=> Self(T.TypeKey, Variant.Create(value));

	public static implicit operator Component.Type(Component v)
		=> .(v.typeKey, v.value.VariantType);

	public struct Type: this(Component.Type.Key typeKey, System.Type type), IComponent.Type
	{
		public Component.Type.Key TypeKey => this.typeKey;
		public System.Type Type => this.type;

		public static Component.Type Create<T>() where T: IComponent, struct
			=> .(T.TypeKey, typeof(T));

		public static Component.Type Create(IComponent.Type componentType)
			=> .(componentType.TypeKey, componentType.Type);

		public static void InitSpan<T>(Span<Component.Type> ret, Span<T> components) where T: IComponent.Type {
			for (let i < ret.Length)
				ret[i] = .Create(components[i]);
		}
		
		public static int64 HeaderSum<T>(params Span<T> header) where T: IComponent.Type {
			int64 headerSum = 0;
			for (let c in header) {
				headerSum += c.TypeKey.value;
			}
			return headerSum;
		}

		public struct Key: this(uint16 value), IHashable, IComponent.Type
		{
			[Inline]
			public int GetHashCode()
				=> value.GetHashCode();

			public Component.Type.Key TypeKey => this;
			public System.Type Type => ThrowUnimplemented();
		}
	}
}

