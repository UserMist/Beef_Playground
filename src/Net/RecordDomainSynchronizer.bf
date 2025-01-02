using System;
using System.Collections;
namespace Playground;

typealias NetTick = uint16;

struct UserID: IHashable
{
	private Guid guid;
	public int GetHashCode()
		=> guid.GetHashCode();
}

class EntityDomainUploader
{
	public NetTick currentTick;
	public EntityDomain domain;

	//repeatedly sent out to users
	public Dictionary<UserID, HashSet<Explanation>> unacknowledgedMessages;

	public struct Explanation: IHashable
	{
		public Header header;
		public EntityId EntityId;
		public EntityInfo entityInfo;

		public enum EntityInfo {
			case DoesntExist;
			case Update(uint8 packetIdx, uint8 packetAmount, bool allFields, (Component.Type.Key compId, String value)[] assignments);
			case SyncChecker(int64 hash); //to account for imperfect hashing 1% of SymcCheckers should be randomly replaced with other cases
		}

		public struct Header: IHashable {
			public typealias CheckSum = uint16;
			public typealias ShortGuid = uint8[12];

			public CheckSum checkSum = default;
			public NetTick snapshotTick;
			public ShortGuid shortGuid;

			public this(NetTick tick) {
				var guid = Guid.Create();
				let guidBytes = (uint8*)&guid;
				shortGuid = ?;
				for (let i < shortGuid.Count) {
					shortGuid[i] = guidBytes[i];
				}

				guid = .Create();
				snapshotTick = tick;
			}

			public int GetHashCode() {
				var shortGuid = this.shortGuid;
				return *(int*)&shortGuid;
			}
		}

		public int GetHashCode()
			=> header.GetHashCode();
	}

	public void WriteExplanation(String bytes, Explanation msg, System.Net.Socket socket, System.Net.Socket.SockAddr_in addr) {
		bytes.Clear();
		var msgHeader = msg.header;
		let msgHeaderPtr = (Explanation.Header*)bytes.Ptr;
		bytes.Append((char8*)&msgHeader, sizeof(Explanation.Header));

		var EntityId = msg.EntityId;
		bytes.Append((char8*)&EntityId, sizeof(EntityId));

		switch (msg.entityInfo) {
		  case .DoesntExist:
			writeByte(bytes, 0);
		  case .Update(let idx, let outOf, let assignments):
			writeByte(bytes, 1);
			writeByte(bytes, idx);
			writeByte(bytes, outOf);
			writeByte(bytes, assignments.Count);
			for (let assignment in assignments) {
				writeString255(bytes, assignment.name);
				writeString255(bytes, assignment.value);
			}
		  case .CompositionCheck(let names):
			writeByte(bytes, 2);
			writeByte(bytes, names.Count);
			for (let name in names) {
				writeString255(bytes, name);
			}
		  default: ThrowUnimplemented();
		}

		msgHeaderPtr.checkSum = CheckSum(bytes);
		socket.SendTo(bytes.Ptr, bytes.Length, addr);
	}

	public static Explanation.Header.CheckSum CheckSum(StringView bytes) {
		let cellSize = sizeof(Explanation.Header.CheckSum);
		let byteLength = bytes.Length;
		Explanation.Header.CheckSum sum = 0;
		var pos = cellSize;
		for (; pos < byteLength; pos += cellSize) {
			sum += *(Explanation.Header.CheckSum*)&bytes[pos];
		}
		System.Diagnostics.Debug.Assert(pos < byteLength);
		for (; pos < byteLength; pos++) {
			sum += (uint8)bytes[pos];
		}
		return sum;
	}

	private static void writeByte(String bytes, int src) {
		bytes.Append((char8)(uint8)src);
	}

	private static void writeString255(String bytes, StringView src) {
		bytes.Append((char8)(uint8)src.Length);
		bytes.Append(src);
	}
}

class EntityDomainDownloader
{
	//things to consider at every step of implementation:
	// explanation arrives too late and out of order (only a problem when simulation when our snapshots do not capture that tick.
	//         If so, we preferably query it again, since applying it to oldest tick loses information about which update was first)
	// explanation did not arrive (see messagesToAcknowledge)
	// explanation did arrive duplicated (see knownMessages)
	public List<(NetTick tick, EntityDomain domain)> snapshots;

	enum AppliedExplanation {
		case None;
		case BeingQueried;
		case Destroyed;
		case Update(bool allFields, uint8 done, uint8 outOf);
	}

	public List<(EntityId, int)> syncQueries; 
	public Dictionary<EntityId, (NetTick tick, uint8 updates)> lastUpdatedEntities; //used to build entitiesToQuery, and to determine if 
	public List<EntityDomainUploader.Explanation.Header> knownMessages;
	public List<EntityDomainUploader.Explanation.Header> messagesToAcknowledge;

	public Result<EntityDomainUploader.Explanation> ReadExplanation(StringView src) {
		var pos = 0;
		let header = read<EntityDomainUploader.Explanation.Header>(src, &pos);
		if (knownMessages.Contains(header) || header.checkSum != EntityDomainUploader.CheckSum(src)) {
			return .Err;
		}
		
		EntityDomainUploader.Explanation ret = ?;
		knownMessages.Add(ret.header = header);
		ret.EntityId = read<EntityId>(src, &pos);
		switch (read<uint8>(src, &pos)) {
		  case 0:
			ret.entityInfo = .DoesntExist;
		  case 1:
			let count = read<uint8>(src, &pos);
			let idx = read<uint8>(src, &pos);
			let outOf = read<uint8>(src, &pos);
			(String name, String value)[] names = new .[count];
			for (let i < count) {
				names[i].name = readString255(src, &pos);
				names[i].value = readString255(src, &pos);
			}
			ret.entityInfo = .Update(idx, outOf, names);
		  case 2:
			let count = read<uint8>(src, &pos);
			let names = new String[count];
			for (let i < count) {
				names[i] = readString255(src, &pos);
			}
			ret.entityInfo = .CompositionCheck(names);
		  default: ThrowUnimplemented();
		}
		return ret;
	}

	private T read<T>(StringView src, int* pos) {
		let ret = *(T*)(&src.Ptr[*pos]);
		*pos += sizeof(T);
		return ret;
	}

	private static String readString255(StringView src, int* pos) {
		let length = (uint8)src[*pos];
		let ret = new String(length);
		ret.Append(src.Substring(1, length));
		*pos += length+1;
		return ret;
	}

	public void ApplyMessage(EntityDomainUploader.Explanation message) {
		//clamp it to current snapshot, or to oldest snapshot (make sure reordering doesn't happen)
		var message;
		let firstTick = snapshots[0].tick;
		let lastTick = snapshots[^1].tick;

		if (firstTick > lastTick) {
			message.header.snapshotTick = Math.Min(message.header.snapshotTick, lastTick);
		} else {

		}
	}
}