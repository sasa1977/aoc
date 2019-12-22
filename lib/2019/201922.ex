defmodule Aoc201922 do
  def run do
    Aoc.output(&part1/0)
  end

  defp part1, do: Enum.reduce(transformers(), 2019, & &1.(10_007, &2))

  defp transformers, do: Stream.map(Aoc.input_lines(__MODULE__), &transformer/1)

  defp transformer("deal into new stack"), do: deal_into_new_stack()
  defp transformer("cut " <> size), do: cut(String.to_integer(size))
  defp transformer("deal with increment " <> step), do: deal_with_increment(String.to_integer(step))

  defp deal_into_new_stack(), do: fn deck_size, pos -> deck_size - 1 - pos end
  defp cut(size), do: fn deck_size, pos -> rem(pos - size, deck_size) end
  defp deal_with_increment(step), do: fn deck_size, pos -> rem(pos * step, deck_size) end
end
