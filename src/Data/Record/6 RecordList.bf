using System;
using System.Collections;
namespace Playground.Data.Record;

interface IUniformRecords
{
	int Count { get; }
	void GetHeader(List<IComponent.Type> types);
	bool HasOnly(params Span<IComponent.Type> types);
	bool Includes(params Span<IComponent.Type> types);
	bool Excludes(params Span<IComponent.Type> types);
}

interface IRecordList: IUniformRecords
{
	void GetPtrAndStride(IComponent.Type type, out void* ptr, out int stride);

	/*
	void GetStridedSpan<T>(out StridedSpan<T> span) where T: IComponent, ValueType {
		GetPtrAndStride(Component.Type.Create<T>(), let ptr, let stride);
		span = .(ptr, stride, ((IUniformRecords) this).Count);
	}
	*/

	Component? Add(bool resizeAllowed, params Span<Component> values)
		=> ThrowUnimplemented();

	bool Remove(Component primaryKey, bool instantly = false, bool destroy = true)
		=> ThrowUnimplemented();
}

interface IRecordTable: IUniformRecords
{
	void GetStrider() {

	}
}