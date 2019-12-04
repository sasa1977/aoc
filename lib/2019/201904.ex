defmodule Aoc201904 do
  def run() do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1(), do: Enum.count(valid_passwords(147_981..691_423))

  defp part2() do
    valid_passwords(147_981..691_423)
    |> Stream.filter(&isolated_adjacent?/1)
    |> Enum.count()
  end

  defp isolated_adjacent?(num) do
    num
    |> Integer.digits()
    |> Stream.chunk_by(& &1)
    |> Enum.any?(&match?([_, _], &1))
  end

  defp valid_passwords(range) do
    Stream.unfold(
      range.first,
      fn candidate ->
        next_valid_password = next_valid_password(candidate)
        {next_valid_password, next_valid_password + 1}
      end
    )
    |> Stream.take_while(&(&1 <= range.last))
  end

  defp next_valid_password(candidate) do
    candidate
    |> valid_prefix()
    |> complete_password()
    |> Integer.undigits()
  end

  defp valid_prefix(candidate) do
    [0 | Integer.digits(candidate)]
    |> Stream.chunk_every(2, 1, :discard)
    |> Stream.take_while(fn [prev_digit, digit] -> digit >= prev_digit end)
    |> Enum.map(fn [_, digit] -> digit end)
  end

  defp complete_password([a, b, c, d, e, f] = digits) do
    if a == b or b == c or c == d or d == e or e == f,
      # digits form a valid password, so return them
      do: digits,
      # digits are strictly monotonoic, so the next valid password is abcdff
      else: [a, b, c, d, f, f]
  end

  defp complete_password(prefix) when length(prefix) < 6 do
    # prefix is not complete -> repeat the last digit to complete the number
    last_digit = List.last(prefix)
    prefix ++ List.duplicate(last_digit, 6 - length(prefix))
  end
end
