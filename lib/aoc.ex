defmodule Aoc do
  def input_file(year, day),
    do: Path.join([Application.app_dir(:aoc, "priv"), "#{year}", "day#{day}.in"])
end
