defmodule Aoc do
  def input_file(year, day),
    do: Path.join([Application.app_dir(:aoc, "priv"), "#{year}", "day#{day}.in"])

  def input_lines(year, day) do
    input_file(year, day)
    |> File.stream!()
    |> Stream.map(&String.trim/1)
  end
end
