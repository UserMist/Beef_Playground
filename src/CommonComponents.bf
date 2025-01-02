using System;
using System.Collections;
using Playground.Data;
namespace Playground.Data.Entity.Components;

[Component(0x7ccd73f4)]
public struct Camera: this(Cage3<float> viewBox, bool perspective), IComponent {

}

[Component(0xc7e5b923, typeof(float3))]
public struct ClipPos3f: float3, IComponent { }

[Component(0xcf67843b, typeof(float3))]
public struct Pos3f: float3, IComponent { }

[Component(0xbacdba69, typeof(float2))]
public struct Pos2f: float2, IComponent { }
	
[Component(0xe2156804, typeof(double3))]
public struct Pos3: double3, IComponent { }
	
[Component(0x3953e680, typeof(float3))]
public struct OldPos3f: float3, IComponent { }
	
[Component(0x91125215, typeof(float3))]
public struct Vel3f: float3, IComponent { }

[Component(0xc6d09fbb, typeof(float2))]
public struct Vel2f: float2, IComponent { }

[Component(0xe079ad65, typeof(float3))]
public struct RotVel3f: float3, IComponent { }



[Component(0x0bdc3abd)]
public struct IOAxis: this(String name, double value, double delta), IComponent {
	public float valueF => .(value);
	public float deltaF => .(delta);
}

[Component(0x4d53bf47)]
public struct IOCanvas: this(Grid2<RGB> image, EntityId renderedBy, Cage3<float> region = .(.All(-1), .All(+1))), IComponent {
	public float3 size = default, offset = default;

	public void RefreshMatrix(Camera cam, float3 pos) mut {
		size = 0.5f * cam.viewBox.dimensions() * .((.)image.widthRatio, 1, 1) / region.dimensions();
		offset = -(pos+cam.viewBox.calculateCenter()+region.calculateCenter());
	}

	public void DrawLine(float3 a, float3 b, RGB value) {
		image.DrawLine(offset + a*size, offset + b*size, value);
	}
}

[Component(0xe9ba9c4a)]
public struct UIRegion: this(List<EntityDomain> panelContents, List<float> panelOffsets), IComponent;
[Component(0xbe46b538)]
public struct UISize: this(float3 size, bool[3] clipCoordsEnabled, Cage3<float> cage), IComponent;
[Component(0xdfc30286)]
public struct UIPositionRule: this(float3 resizeAnchor, float parallax), IComponent;

[Component(0x588d1ae2)]
public struct UIValue: this(HashSet<String> acceptedTypes, String clipboardDump, List<(String, EntityId)> connections), IComponent;
[Component(0x8287dd51)]
public struct UIOutputOnly: this(bool isGreyedInput), IComponent;

[Component(0x7c17a992)]
public struct UISubmitter: this(Dictionary<String, EntityId> argIds, delegate void(Dictionary<String, String> args, String result, UIVisualizer ui) act), IComponent; //can be attached to fields to autosubmit them
[Component(0x79ef4617)]
public struct UIValidator: this(Dictionary<String, EntityId> argIds, delegate void(Dictionary<String, String> args, String result) validator), IComponent;

//todo: on hover (highlight, dropdown, hint, desc)
