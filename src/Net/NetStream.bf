using System;
using System.Net;
using System.IO;
namespace Playground;

class NetStream: Stream
{
	public Socket RSocket ~ if(_ != null) delete _;
	public Socket WSocket ~ if(_ != null) delete _;

	private bool canRead;
	private bool canWrite;
	private int64 length;
	private int64 position;

	public override bool CanRead => RSocket != null;
	public override bool CanWrite => WSocket != null;
	public override int64 Length => length;
	public override int64 Position {
		get => position;
		set => position = value;
	}

	public this() {
	}

	public void WriteTo() {
		WSocket = new .();
	}

	public void ReadFrom() {
		RSocket = new .();
	}

	public override Result<int> TryRead(Span<uint8> data) {
		if (!CanRead) return .Err;
		let reader = scope Socket(); defer reader.Close();

		reader.AcceptFrom(RSocket);

		return default;
	}

	public override Result<int> TryWrite(Span<uint8> data) {
		if (!CanWrite) return .Err;
		return default;
	}

	public override Result<void> Close() {
		RSocket.Close();
		return .Ok;
	}
}