using static System.Math;
namespace Playground;

class ShapeTools
{
	/// UNDEFINED CASE: Intersection of line with parallel box wall.
	public static bool RayBoxIntersection(float3 rayOrigin, float3 rayDirection, float3 boxMin, float3 boxMax, out float minDist, out float maxDist) {
		//Multiplication is needed for it to register hits parallel to walls
		float3 m = 1f/rayDirection;
		var distsToMin = (boxMin - rayOrigin)*m;
		var distsToMax = (boxMax - rayOrigin)*m;
		float3 frontDists = Min(distsToMin, distsToMax);
		float3 backDists = Max(distsToMin, distsToMax);
		minDist = Max(frontDists.x, frontDists.y, frontDists.z); //distance to plane-triplet that is furthest behind our back
		maxDist = Min(backDists.x, backDists.y, backDists.z); //distance to plane-triplet that is furthest to the front 
		//When directional line misses box, distB < distA.
		//To turn directional line into a ray, also add check of distB > 0
		return minDist < maxDist && maxDist > 0;
	}
}