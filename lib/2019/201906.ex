defmodule Aoc201906 do
  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1, do: total_number_of_orbits(graph(), "COM", 0)

  defp part2 do
    graph = graph()
    [my_orbitee] = :digraph.out_neighbours(graph, "YOU")
    [their_orbitee] = :digraph.out_neighbours(graph, "SAN")

    Enum.each(direct_orbits(), fn [to, from] -> :digraph.add_edge(graph, to, from) end)
    length(:digraph.get_short_path(graph, my_orbitee, their_orbitee)) - 1
  end

  defp total_number_of_orbits(graph, object, distance) do
    orbitees = :digraph.in_neighbours(graph, object)

    distance +
      (orbitees
       |> Stream.map(&total_number_of_orbits(graph, &1, distance + 1))
       |> Enum.sum())
  end

  defp graph() do
    Enum.reduce(
      direct_orbits(),
      :digraph.new(),
      fn [to, from], graph ->
        :digraph.add_vertex(graph, from)
        :digraph.add_vertex(graph, to)
        :digraph.add_edge(graph, from, to)
        graph
      end
    )
  end

  defp direct_orbits(),
    do: Stream.map(Aoc.input_lines(2019, 06), &String.split(&1, ")"))
end
