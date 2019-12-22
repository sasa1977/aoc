defmodule Aoc201922 do
  def run do
    Aoc.output(&part1/0)
  end

  defp part1() do
    Enum.reduce(commands(), new_deck(10006), & &1.(&2)) |> Enum.find_index(&(&1 == 2019))
  end

  defp commands(), do: Stream.map(Aoc.input_lines(__MODULE__), &command/1)

  defp command("deal into new stack"), do: &deal_into_new_stack/1

  defp command("cut " <> amount) do
    amount = String.to_integer(amount)
    &cut(&1, amount)
  end

  defp command("deal with increment " <> amount) do
    amount = String.to_integer(amount)
    &deal_with_increment(&1, amount)
  end

  defp new_deck(size), do: 0..size

  defp deal_into_new_stack(deck), do: Enum.reverse(deck)

  defp cut(deck, count) do
    {top, bottom} = Enum.split(deck, count)
    Enum.concat(bottom, top)
  end

  defp deal_with_increment(deck, step) do
    {cards, rest} = Enum.split(deck, 10007)

    0
    |> Stream.iterate(&rem(&1 + step, 10007))
    |> Stream.zip(cards)
    |> Enum.sort_by(fn {pos, _card} -> pos end)
    |> Stream.map(fn {_pos, card} -> card end)
    |> Enum.concat(rest)
  end
end
