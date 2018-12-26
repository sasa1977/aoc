defmodule Aoc201801 do
  def run() do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1() do
    frequency_changes()
    |> frequencies()
    |> Enum.at(-1)
  end

  defp part2() do
    frequency_changes()
    |> Stream.cycle()
    |> frequencies()
    |> Aoc.EnumHelper.non_uniques()
    |> Enum.at(0)
  end

  defp frequency_changes(), do: Aoc.input_lines(2018, 1) |> Stream.map(&String.to_integer/1)

  defp frequencies(frequency_changes) do
    Stream.scan(
      frequency_changes,
      0,
      fn frequency_change, frequency -> frequency + frequency_change end
    )
  end
end
