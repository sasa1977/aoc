defmodule Aoc201924 do
  def run do
    Aoc.output(&part1/0)
    Aoc.output(&part2/0)
  end

  defp part1 do
    biodiversity_ratings = biodiversity_ratings()

    bugs()
    |> Stream.iterate(fn bugs -> next_state(bugs, &simple_adjacent_bugs/1) end)
    |> Aoc.EnumHelper.non_uniques()
    |> Enum.at(0)
    |> bugs_at_level(0)
    |> Stream.map(&Map.fetch!(biodiversity_ratings, &1))
    |> Enum.sum()
  end

  defp part2 do
    bugs()
    |> Stream.iterate(fn bugs -> next_state(bugs, &complex_adjacent_bugs/1) end)
    |> Enum.at(200)
    |> Stream.map(fn {_level, bugs} -> bugs |> MapSet.delete({2, 2}) |> Enum.count() end)
    |> Enum.sum()
  end

  defp simple_adjacent_bugs({x, y}) do
    Stream.map(
      [{1, 0}, {-1, 0}, {0, 1}, {0, -1}],
      fn {dx, dy} -> {{x + dx, y + dy}, 0} end
    )
  end

  outer_adjacent_map = %{
    {:x, 0} => {1, 2},
    {:x, 4} => {3, 2},
    {:y, 0} => {2, 1},
    {:y, 4} => {2, 3}
  }

  @outer_adjacency for x <- 0..4,
                       y <- 0..4,
                       into: %{},
                       do: {{x, y}, outer_adjacent_map |> Map.take([{:x, x}, {:y, y}]) |> Map.values()}

  @inner_adjacency (for {inner, outers} <- @outer_adjacency,
                        outer <- outers,
                        reduce: %{} do
                      acc -> Map.update(acc, outer, [inner], &[inner | &1])
                    end)

  defp complex_adjacent_bugs(pos) do
    simple_adjacent = simple_adjacent_bugs(pos) |> Stream.reject(&match?({{2, 2}, _level}, &1))
    outer_adjacent = Map.fetch!(@outer_adjacency, pos) |> Stream.map(&{&1, 1})
    inner_adjacent = Map.get(@inner_adjacency, pos, []) |> Stream.map(&{&1, -1})
    Enum.concat([simple_adjacent, outer_adjacent, inner_adjacent])
  end

  defp biodiversity_ratings() do
    Stream.iterate(1, &(&1 * 2))
    |> Stream.zip(coordinates())
    |> Enum.into(%{}, fn {score, pos} -> {pos, score} end)
  end

  defp next_state(bugs, adjacency_fun) do
    {min_level, max_level} = Map.keys(bugs) |> Enum.min_max()

    (min_level - 1)..(max_level + 1)
    |> Stream.map(&{&1, next_state(bugs, &1, adjacency_fun)})
    |> Stream.reject(fn {_level, bugs} -> Enum.empty?(bugs) end)
    |> Map.new()
  end

  defp next_state(bugs, level, adjacency_fun) do
    for pos <- coordinates(),
        bug_at_next_state?(bugs, pos, level, adjacency_fun),
        into: MapSet.new(),
        do: pos
  end

  defp coordinates() do
    Stream.iterate(
      {0, 0},
      fn
        {4, y} -> {0, y + 1}
        {x, y} -> {x + 1, y}
      end
    )
    |> Stream.take_while(fn {_x, y} -> y < 5 end)
  end

  defp bug_at_next_state?(bugs, pos, level, adjacency_fun) do
    current_bug? = bug?(bugs, pos, level)

    adjacent_bugs_num =
      adjacency_fun.(pos)
      |> Stream.filter(fn {pos, delta_level} -> bug?(bugs, pos, level + delta_level) end)
      |> Enum.count()

    cond do
      current_bug? and adjacent_bugs_num != 1 -> false
      not current_bug? and adjacent_bugs_num in 1..2 -> true
      true -> current_bug?
    end
  end

  defp bug?(bugs, pos, level) do
    bugs
    |> bugs_at_level(level)
    |> MapSet.member?(pos)
  end

  defp bugs_at_level(bugs, level), do: Map.get(bugs, level, MapSet.new())

  defp bugs() do
    %{
      0 =>
        Aoc.map(__MODULE__)
        |> Stream.filter(&match?({_pos, ?#}, &1))
        |> Stream.map(fn {pos, ?#} -> pos end)
        |> MapSet.new()
    }
  end
end
