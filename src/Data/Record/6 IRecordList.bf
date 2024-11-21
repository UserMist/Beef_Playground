using System;
using System.Collections;
using Playground.Data.Record.Components;
namespace Playground.Data.Record;

interface IRecordTable
{
	int Count { get; }
	void GetHeader(List<IComponent.Type> types);
	bool HasOnly(params Span<IComponent.Type> types);
	bool Includes(params Span<IComponent.Type> types);
	bool Excludes(params Span<IComponent.Type> types);

	int ChunkCount { get; }
	void GetPtrAndStride(IComponent.Type type, int chunkIdx, out void* ptr, out int stride);

	public bool UsesStridedSpans => true;

	/*
	void GetStridedSpan<T>(out StridedSpan<T> span) where T: IComponent, ValueType {
		GetPtrAndStride(Component.Type.Create<T>(), let ptr, let stride);
		span = .(ptr, stride, ((IUniformRecords) this).Count);
	}
	*/
	
	RecordId Add(bool resizeAllowed, params Span<Component> values)
		=> ThrowUnimplemented();

	bool Remove(RecordId id, bool destroy = true)
		=> ThrowUnimplemented();

	void AddLast(bool resizeAllowed, params Span<Component> values)
		=> ThrowUnimplemented();

	void Remove(int id, bool destroy = true)
		=> ThrowUnimplemented();
}