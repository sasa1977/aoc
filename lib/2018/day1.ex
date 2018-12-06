defmodule Aoc201801 do
  def run() do
    frequency_changes = Aoc.input_lines(2018, 1) |> Stream.map(&String.to_integer/1)
    part1(frequency_changes) |> IO.inspect()
    part2(frequency_changes) |> IO.inspect()
  end

  defp part1(frequency_changes) do
    frequency_changes
    |> frequencies()
    |> Aoc.EnumHelper.last_element()
  end

  defp part2(frequency_changes) do
    frequency_changes
    |> Stream.cycle()
    |> frequencies()
    |> Stream.transform(
      MapSet.new(),
      fn frequency, frequencies ->
        if MapSet.member?(frequencies, frequency),
          do: {[frequency], frequencies},
          else: {[], MapSet.put(frequencies, frequency)}
      end
    )
    |> Aoc.EnumHelper.first_element()
  end

  defp frequencies(frequency_changes) do
    Stream.scan(
      frequency_changes,
      0,
      fn frequency_change, frequency -> frequency + frequency_change end
    )
  end
end
