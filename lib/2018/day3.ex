defmodule Aoc201803 do
  def run() do
    part1() |> IO.inspect()
    part2() |> IO.inspect()
  end

  defp part1() do
    claims()
    |> intersections()
    |> Stream.flat_map(&points/1)
    |> Stream.uniq()
    |> Enum.count()
  end

  defp part2() do
    overlapping_claims =
      claims()
      |> intersections()
      |> Stream.flat_map(& &1.claims)
      |> MapSet.new()

    all_claims =
      claims()
      |> Stream.map(& &1.id)
      |> MapSet.new()

    MapSet.difference(all_claims, overlapping_claims)
    |> Enum.to_list()
    |> hd()
  end

  defp points(intersection) do
    for x <- intersection.left..intersection.right,
        y <- intersection.top..intersection.bottom,
        do: {x, y}
  end

  defp intersections([claim | others]) do
    others
    |> Stream.map(&intersection(claim, &1))
    |> Stream.concat(intersections(others))
    |> Stream.reject(&is_nil/1)
  end

  defp intersections([]), do: []

  defp intersection(claim1, claim2) do
    left = max(claim1.left, claim2.left)
    right = min(claim1.right, claim2.right)
    top = min(claim1.top, claim2.top)
    bottom = max(claim1.bottom, claim2.bottom)

    if left <= right and bottom <= top,
      do: %{left: left, right: right, top: top, bottom: bottom, claims: [claim1.id, claim2.id]}
  end

  defp claims(), do: Aoc.input_lines(2018, 3) |> Enum.map(&parse_rectangle/1)

  defp parse_rectangle(encoded_rectangle) do
    captures =
      Regex.named_captures(
        ~r/#(?<id>\d+) @ (?<x>\d+),(?<y>\d+): (?<width>\d+)x(?<height>\d+)/,
        encoded_rectangle
      )

    left = captures |> Map.fetch!("x") |> String.to_integer()
    top = -(captures |> Map.fetch!("y") |> String.to_integer())

    %{
      id: captures |> Map.fetch!("id") |> String.to_integer(),
      left: left,
      top: top,
      right: left + (captures |> Map.fetch!("width") |> String.to_integer()) - 1,
      bottom: top - (captures |> Map.fetch!("height") |> String.to_integer()) + 1
    }
  end
end
