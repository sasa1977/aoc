defmodule Aoc201802 do
  def run() do
    part1() |> IO.inspect()
    part2() |> IO.puts()
  end

  defp part1() do
    letters_by_counts = Enum.map(ids(), &letters_by_counts/1)
    count_occurrences(letters_by_counts, 2) * count_occurrences(letters_by_counts, 3)
  end

  defp part2(), do: ids() |> Enum.to_list() |> find()

  def find([id | rest]) do
    rest
    |> Stream.map(&diff(id, &1))
    |> Enum.find(&match?({_same, [_] = _different}, &1))
    |> case do
      nil -> find(rest)
      {same, _different} -> same |> Enum.map(fn {char, char} -> char end) |> to_string()
    end
  end

  defp diff(id1, id2) do
    Stream.zip(to_charlist(id1), to_charlist(id2))
    |> Enum.split_with(&match?({&1, &1}, &1))
  end

  defp count_occurrences(letters_by_counts, count) do
    letters_by_counts
    |> Stream.filter(&Map.has_key?(&1, count))
    |> Enum.count()
  end

  defp letters_by_counts(id) do
    id
    |> to_charlist()
    |> Aoc.EnumHelper.frequencies()
    |> Enum.group_by(fn {_char, value} -> value end, fn {char, _value} -> char end)
  end

  defp ids(), do: Aoc.input_lines(2018, 2)
end
