using System;
using System.Net;
using System.Threading;
using System.Diagnostics;
using System.Collections;
namespace Playground;

public class NetReader: this(IDumper dumper), IDisposable
{
	public Thread thread;
	public int? port;
	public Queue<void*> output = new .() ~ delete _;

	public ~this() {
		Dispose();
	}
	
	public void Dispose() {
		if (port == null) {
			return;
		}

		port = null;
		thread.Join();
	}

	public void UsePort(int? newPort) {
		Dispose();
		if ((port = newPort) == null) { return; }

		thread = new Thread(new () => ThreadMethod())..Start();
	}

	public virtual void ThreadMethod() {
		let me = scope Socket(); defer me.Close();
		if (me.OpenUDP((.)port) case .Err) {
			Console.WriteLine(scope $"Failed opening port {port}");
			return;
		}

		let oldPort = port;
		Console.WriteLine(scope $"Opened port {oldPort}");
		defer { Console.WriteLine(scope $"Closed port {oldPort}"); }
		Process(me);
	}

	public virtual void Process(Socket me) {
		while (port != null) {
			let client = scope Socket(); defer client.Close();
			if (client.AcceptFrom(me) case .Err) {
				continue;
			}

			var inLength = int32();
			client.Recv(&inLength, 4);
			var buffer = new uint8[inLength]; defer delete buffer;

			let item = dumper.AllocateDumpHolder();
			dumper.ProcessDump(.Update(&StringView((.)buffer.Ptr, buffer.Count)), item);
			output.Add(item);
		}
	}
}