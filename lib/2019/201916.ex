defmodule Aoc201916 do
  def run do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1 do
    elements()
    |> Stream.iterate(&next_phase/1)
    |> message()
  end

  defp part2 do
    elements = elements() |> List.duplicate(10_000) |> List.flatten()
    target_pos = elements |> Stream.take(7) |> Enum.reduce(0, &(&2 * 10 + &1))

    # this solution works only if the target sequence is in the second half
    true = target_pos >= div(length(elements), 2)

    elements
    |> Enum.drop(target_pos)
    |> Stream.iterate(&next_phase_naive/1)
    |> message()
  end

  # Naive computation of the next phase. This function assumes that we're computing the digits in the second half
  # of the input. In such case, we can compute next sequence by cummulatively adding elements from the end.
  # In other words, given the input sequence (a, b, c), the next sequence is (rem(a+b+c, 10), rem(b+c, 10), rem(c, 10)).
  defp next_phase_naive(elements) do
    {_, elements} =
      List.foldr(
        elements,
        {0, []},
        fn element, {sum, elements} -> {sum + element, [sum + element | elements]} end
      )

    Enum.map(elements, &rem(&1, 10))
  end

  defp next_phase(elements) do
    elements = List.to_tuple(elements)
    Enum.map(1..tuple_size(elements), &nth_element(elements, &1))
  end

  defp nth_element(elements, n) do
    elements
    # skip `n-1` (n is 1-based) elements since there are as many leading zeroes in the pattern
    |> sum_elements(n, n - 1, true)
    |> abs()
    |> rem(10)
  end

  defp sum_elements(elements, _pattern_size, pos, _positive?) when pos >= tuple_size(elements),
    do: 0

  defp sum_elements(elements, pattern_size, pos, positive?) do
    final_pos = min(pos + pattern_size, tuple_size(elements)) - 1
    factor = if positive?, do: 1, else: -1

    pattern_sum = factor * Enum.reduce(pos..final_pos, 0, &(elem(elements, &1) + &2))
    remaining_sum = sum_elements(elements, pattern_size, final_pos + 1 + pattern_size, not positive?)

    pattern_sum + remaining_sum
  end

  defp message(fft_phases), do: fft_phases |> Enum.at(100) |> Stream.take(8) |> Enum.join()

  defp elements() do
    Aoc.input_file(__MODULE__)
    |> File.read!()
    |> String.trim()
    |> String.to_charlist()
    |> Enum.map(&(&1 - ?0))
  end
end
