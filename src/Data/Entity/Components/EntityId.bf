using System;
namespace Playground.Data.Entity.Components;

[Component(1)]
public struct EntityId: this(uint32 indexer, uint32 idx), IComponent, IHashable
{
	public int GetHashCode()
		=> indexer + idx;
}