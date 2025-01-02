namespace System;

extension Random
{
	public double NextDouble(double min, double max)
		=> min + NextDouble() * (max - min);
}