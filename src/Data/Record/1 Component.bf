using System;
namespace Playground.Data.Record;

public struct Component: this(Component.Type.Key typeKey, Component.Destructor destructor, Variant value), IDisposable, IComponent.Type
{
	public Component.Type.Key TypeKey => this.typeKey;
	public System.Type Type => this.value.VariantType;
	public Component.Destructor Destructor => destructor;

	public typealias Destructor = delegate void(void*);

	public void Dispose() mut
		=> value.Dispose();
	
	public static Self Create<T>(T value) where T: IComponent, struct
		=> Self(T.TypeKey, T.Destructor, Variant.Create(value));

	public static implicit operator Component.Type(Component v)
		=> .(v.typeKey, v.Destructor, v.value.VariantType);

	public struct Type: this(Component.Type.Key typeKey, Component.Destructor destructor, System.Type type), IComponent.Type
	{
		public Component.Type.Key TypeKey => this.typeKey;
		public System.Type Type => this.type;
		public Component.Destructor Destructor => destructor;

		public static Component.Type Create<T>() where T: IComponent, struct
			=> .(T.TypeKey, T.Destructor, typeof(T));

		public static Component.Type Create(IComponent.Type componentType)
			=> .(componentType.TypeKey, componentType.Destructor, componentType.Type);

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

		public struct Key: this(uint32 value), IHashable, IComponent.Type
		{
			[Inline]
			public int GetHashCode()
				=> value.GetHashCode();

			public Component.Type.Key TypeKey => this;
			public System.Type Type => ThrowUnimplemented();
			public Component.Destructor Destructor => ThrowUnimplemented();
		}
	}
}

[AttributeUsage(.Struct)]
public struct ComponentAttribute: this(uint32 typeKey, Type baseType = null), Attribute, IOnTypeInit
{
	[Comptime] public void OnTypeInit(Type type, Self* prev) {
		let code = new String();
		if (baseType != null) {
			let constructors = baseType.GetMethods(.CreateInstance | .Public);
			for (let ctor in constructors) {
				if (!ctor.IsConstructor || ctor.ParamCount == 0)
					continue;
			
				code += "public this(";
				ctor.GetParamsDecl(code);
				code += ") : base(";
				for (let i < ctor.ParamCount) {
					if (i > 0)
						code += ", ";
					code += ctor.GetParamName(i);
				}
				code += ") { }\n";
			}
		}

		Compiler.EmitTypeBody(type, scope $"""
		public static Component.Type.Key TypeKey => .({typeKey});
		public static Component.Type AsType => .Create<{type.GetName(..scope .())}>();
		public static implicit operator Component(Self v) => .Create(v);
		{code}
		""");
	}
}
