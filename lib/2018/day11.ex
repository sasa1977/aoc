defmodule Aoc201811 do
  @grid_size 300
  @grid_serial_number 7347

  def run() do
    summed_area = summed_area()
    part1(summed_area) |> IO.puts()
    part2(summed_area) |> IO.puts()
  end

  defp part1(summed_area) do
    best = best_square(summed_area, 3)
    "#{best.x},#{best.y}"
  end

  defp part2(summed_area) do
    best =
      1..@grid_size
      |> Task.async_stream(&best_square(summed_area, &1), timeout: :infinity)
      |> Stream.map(fn {:ok, best} -> best end)
      |> Enum.max_by(& &1.value)

    "#{best.x},#{best.y},#{best.square_size}"
  end

  defp summed_area(square \\ power_levels()) do
    # see https://en.wikipedia.org/wiki/Summed-area_table for algorithm description
    Enum.reduce(square_coordinates(@grid_size), %{}, &Map.put(&2, &1, sat_value(&2, &1, square)))
  end

  defp sat_value(summed_area, {x, y}, original) do
    Map.get(original, {x, y}, 0) + Map.get(summed_area, {x, y - 1}, 0) + Map.get(summed_area, {x - 1, y}, 0) -
      Map.get(summed_area, {x - 1, y - 1}, 0)
  end

  defp best_square(summed_area, square_size),
    do: Enum.reduce(square_coordinates(@grid_size - square_size + 1), nil, &better(summed_area, square_size, &1, &2))

  defp better(summed_area, square_size, {x, y}, current_best) do
    value = square_power_level(summed_area, x, y, square_size)

    if current_best == nil or value > current_best.value,
      do: %{value: value, x: x, y: y, square_size: square_size},
      else: current_best
  end

  defp square_power_level(summed_area, x, y, square_size) do
    a = Map.get(summed_area, {x - 1, y - 1}, 0)
    b = Map.get(summed_area, {x + square_size - 1, y - 1}, 0)
    c = Map.get(summed_area, {x - 1, y + square_size - 1}, 0)
    d = Map.get(summed_area, {x + square_size - 1, y + square_size - 1}, 0)
    d + a - b - c
  end

  defp power_levels(), do: square_coordinates(@grid_size) |> Stream.map(&{&1, power_level(&1)}) |> Map.new()

  defp power_level({x, y}) do
    rack_id = x + 10
    hundreds_digit((rack_id * y + @grid_serial_number) * rack_id) - 5
  end

  defp hundreds_digit(number), do: number |> rem(1000) |> div(100)

  defp square_coordinates(square_size) do
    {1, 1}
    |> Stream.iterate(fn {x, y} -> if x < square_size, do: {x + 1, y}, else: {1, y + 1} end)
    |> Stream.take_while(fn {_x, y} -> y <= square_size end)
  end
end
