namespace Playground.Data;
using System;

static class SDF2
{
	public static float CapsuleF(float2 sampler, float2 ap, float2 bp) {
		let vec = bp - ap;
		if (dot(sampler - ap, vec) * dot(sampler - bp, vec) >= 0) {
			let aDist = Math.Distance(ap.x - sampler.x, ap.y - sampler.y);
			let bDist = Math.Distance(bp.x - sampler.x, bp.y - sampler.y);
			return Math.Min(aDist, bDist);
		}
		let dist = Math.Distance(vec.x, vec.y);
		if (dist < float.Epsilon) {
			return dist;
		}
		let norm = vec * (1f / dist);
		return Math.Abs(norm.x*(ap.y - sampler.y) - norm.y*(ap.x - sampler.x));
	}

	private static float dot(float2 a, float2 b)
		=> a.x*b.x + a.y*b.y;
}