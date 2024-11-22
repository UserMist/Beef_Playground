using System;
namespace Playground.Data.Record.Components;

[Component(1)]
public struct RecordId: this(uint32 indexer, uint32 idx), IComponent, IHashable
{
	public int GetHashCode()
		=> Internal.UnsafeCastToPtr(indexer).GetHashCode() | idx;
}