defmodule Aoc do
  def input_file(module) do
    %{"day" => day, "year" => year} =
      Regex.named_captures(
        ~r/.+(?<year>\d{4})(?<day>\d{2})$/,
        inspect(module)
      )

    day = String.replace(day, ~r/^0*/, "")

    Path.join([Application.app_dir(:aoc, "priv"), "#{year}", "day#{day}.in"])
  end

  def input_lines(module) do
    input_file(module)
    |> File.stream!()
    |> Stream.map(&String.trim/1)
  end
end
