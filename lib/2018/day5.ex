defmodule Aoc201805 do
  def run() do
    part1() |> IO.inspect()
    part2() |> IO.inspect()
  end

  defp part1(), do: polymer() |> react() |> polymer_size()

  defp part2() do
    polymer()
    |> unique_units()
    |> Stream.map(&remove_unit(polymer(), &1))
    |> Stream.map(&react/1)
    |> Stream.map(&polymer_size/1)
    |> Enum.min()
  end

  defp unique_units(polymer) do
    polymer
    |> Stream.flat_map(&([&1] |> to_string() |> String.upcase() |> to_charlist()))
    |> Stream.uniq()
  end

  defp remove_unit(polymer, unit),
    do: Enum.reject(polymer, &(&1 == unit or opposite_polarities?(&1, unit)))

  defp react([]), do: []

  defp react([a | rest]) do
    case react(rest) do
      [] -> [a]
      [b | rest] -> react_pair(a, b) ++ rest
    end
  end

  defp react_pair(a, b), do: if(opposite_polarities?(a, b), do: [], else: [a, b])

  defp opposite_polarities?(a, b), do: abs(a - b) == ?a - ?A

  defp polymer() do
    Aoc.input_file(2018, 3)
    |> File.read!()
    |> to_charlist()
    |> Enum.reject(&(&1 == ?\n))
  end

  defp polymer_size(polymer), do: length(polymer)
end
