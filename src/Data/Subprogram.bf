using System;
using System.Collections;
using Playground.Data;
using Playground.Data.Entity;
using Playground.Data.Entity.Components;
namespace Playground;

/// Units that make up programs.
/// They decide 
public abstract class Subprogram
{
	public EntityDomain domain = new .() ~ delete _;

	public virtual void InitIOConnection(IOConnection io) {
		io.data.For("EntityId, ref IOCanvas").Run(scope [&](targetId, target) => {
			if (targetId != io.connectionId)
				return;
			target.renderedBy = SpawnCamera();
		});
		domain.Refresh();
	}

	protected virtual EntityId SpawnCamera()
		=> domain.Add(Camera(Cage3<float>(.All(-1), .All(+1)), false), Vel3f(0,0,0), Pos3f(0,0,0));

	public abstract void UpdateIO(float dt, IOConnection io);
	public abstract void Advance(float dt);
}

public struct IOConnection: this(EntityId connectionId, EntityDomain data)
{
	public void Render(EntityDomain domainWithCameras, delegate void(IOCanvas canvas) render) {
		data.For("EntityId, ref IOCanvas").Run(scope (targetId, target) => {
			if (targetId != connectionId)
				return;
			domainWithCameras.For("EntityId, Camera, Pos3f").Run(scope [&](camId, camera, pos) => {
				if (camId == target.renderedBy)
					render(target..RefreshMatrix(camera, pos));
			});
		});
	}

	public double GetFirstAxis(StringView name) {
		return GetFirstAxis<1>(.(name))[0];
	}

	public double[N] GetFirstAxis<N>(StringView[N] names) where N: const int {
		double[N] ret = default;
		data.For("IOAxis").Run(scope [&](axis) => {
			for (let i < names.Count) if (axis.name == names[i]) {
				ret[i] = axis.value;
			}
		});
		return ret;
	}

	public double GetFirstAxisPrev(StringView name) {
		return GetFirstAxisPrev<1>(.(name))[0];
	}

	public double[N] GetFirstAxisPrev<N>(StringView[N] names) where N: const int {
		double[N] ret = default;
		data.For("IOAxis").Run(scope [&](axis) => {
			for (let i < names.Count) if (axis.name == names[i]) {
				ret[i] = axis.value - axis.delta;
			}
		});
		return ret;
	}
}

//Child classes can include: debug tree graphs, consoles, GUI, HUDs, 3d world-space button objects.
//UI positions are 3d. This makes them applicable for VR and other uses, as well as allows for z-sorting rendered elements
//UI entids need shouldn't change.
public abstract class UIVisualizer: Subprogram
{
	public Dictionary<String, Subprogram> connections = new .() ~ delete _;
	public UIRegion ui;

	public override void Advance(float dt)
		=> NOP!();
}

public class UIMenu: UIVisualizer
{
	public override void UpdateIO(float dt, IOConnection io) {
		render(ui);
	}

	private void render(EntityDomain domain) {
		domain.For("UIRegion").Run(scope (region) => render(region));
	}

	private void render(UIRegion region) {
		for (let panel in region.panelContents) {
			render(panel);
		}
	}
}

public class UIConsole: UIVisualizer
{
	public override void UpdateIO(float dt, IOConnection io) {

	}
}