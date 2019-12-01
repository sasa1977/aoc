defmodule Aoc201901 do
  def run() do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1 do
    module_masses()
    |> Stream.map(&required_fuel_simple/1)
    |> Enum.sum()
  end

  defp part2 do
    module_masses()
    |> Stream.map(&required_fuel_precise/1)
    |> Enum.sum()
  end

  defp module_masses(),
    do: Stream.map(Aoc.input_lines(2019, 1), &String.to_integer/1)

  defp required_fuel_precise(mass) do
    mass
    |> Stream.iterate(&required_fuel_simple/1)
    |> Stream.drop(1)
    |> Stream.take_while(&(&1 > 0))
    |> Enum.sum()
  end

  defp required_fuel_simple(mass),
    do: max((mass |> div(3) |> trunc()) - 2, 0)
end
