using System;
using System.Diagnostics;
namespace Playground;

interface IDumper
{
	public enum Op
	{
		case Update(StringView* view);
		case Send(String buffer);
		case PartialSend(String buffer, void* oldState);
	}
	
	void* AllocateDumpHolder();
	void ProcessDump(Op op, void* item);
	bool IsPartialDumper => false;
}

class RawDumper: this(Type type), IDumper
{
	public void* AllocateDumpHolder() {
		let alloc = (new uint8[type.Size]).Ptr;
		if (type == typeof(String)) {
			*(String*)alloc = new String();
			return alloc;
		}
		return alloc;
	}

	public void ProcessDump(IDumper.Op op, void* item) {
		if (type == typeof(String)) {
			ProcessRawString(op, item);
		} else {
			ProcessRaw(op, (.)item, type.Size);
		}
	}

	public static void ProcessRaw(IDumper.Op op, char8* item, int size) {
		String buffer = ?;
		switch (op) {
		case .Update(let view):
			let ptr = (*view).Ptr;
			*view = view.Substring(size);
			for (let i < size)
				item[i] = ptr[i];
		case .Send(buffer), .PartialSend(buffer, ?):
			let ptr = buffer.Ptr;
			let offset = buffer.Length;
			buffer.Reserve(offset + size);
			for (let i < size)
				ptr[i] = item[i];
			buffer.[Friend]mLength += (.)size;
		default: ThrowUnimplemented();
		}
	}
	
	public static void ProcessRawString(IDumper.Op op, void* item0) {
		let str = *(String*) item0;
		let prefixLength = sizeof(int32);

		String buffer = ?;
		switch (op) {
		case .Update(let view):
			int32 length = ?;
			RawDumper.ProcessRaw(op, (.)&length, prefixLength);
			str.Set(StringView(view.Ptr, length));
		case .Send(buffer), .PartialSend(buffer, ?):
			int32 length = (.)str.Length;
			RawDumper.ProcessRaw(op, (.)&length, prefixLength);
			buffer.Append(str);
		default: ThrowUnimplemented();
		}
	}
}