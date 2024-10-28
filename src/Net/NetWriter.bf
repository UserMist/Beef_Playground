using System;
using System.Net;
using System.Threading;
using System.Diagnostics;
using System.Collections;
namespace Playground;

public class NetWriter: this(IDumper dumper), IDisposable
{
	public Thread thread;
	public int? port;
	public String ip;
	public Queue<void*> input = new .() ~ delete _;

	public ~this() {
		Dispose();
	}
	
	public void Dispose() {
		if (port == null) {
			return;
		}

		port = null;
		thread.Join();
		delete ip;
	}

	public void UseTarget(StringView newIp, int? newPort) {
		Dispose();
		if ((port = newPort) == null) { return; }

		ip = new .(newIp);
		thread = new Thread(new () => ThreadMethod())..Start();
	}
	
	public virtual void ThreadMethod() {
		let me = scope Socket(); defer me.Close();
		if (me.Connect(ip, (.)port) case .Err) {
			Console.WriteLine(scope $"Failed connecting to {ip}:{port}");
			return;
		}

		let oldPort = port;
		Console.WriteLine(scope $"Connected to {ip}:{oldPort}");
		defer { Console.WriteLine(scope $"Closed connection with {ip}:{oldPort}"); }
		Process(me);
	}

	public virtual void Process(Socket me) {
		while (port != null) {
			if (input.IsEmpty) { Thread.Sleep(1); continue; }

			let buffer = new String(); defer delete buffer;
			dumper.ProcessDump(.Send(buffer), input.PopFront());

			var prefix = (int32)buffer.Length;
			buffer.Insert(0, StringView((.)&prefix, sizeof(int32)));
			me.Send(buffer.Ptr, buffer.Length);
		}
	}
}