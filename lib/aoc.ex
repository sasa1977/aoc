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

  def input_lines(module, trimmer \\ &String.trim/1) do
    input_file(module)
    |> File.stream!()
    |> Stream.map(trimmer)
  end

  def output(fun) do
    {time, solution} = :timer.tc(fun)
    if is_binary(solution), do: IO.puts(solution), else: IO.inspect(solution)
    IO.puts("#{IO.ANSI.light_black()}#{div(time, 1000)} ms#{IO.ANSI.reset()}\n")
  end

  def map(module) do
    input_lines(module)
    |> Stream.with_index()
    |> Stream.flat_map(&map_elements/1)
  end

  defp map_elements({line, y}) do
    line
    |> to_charlist()
    |> Stream.with_index()
    |> Stream.map(fn {element, x} -> {{x, y}, element} end)
  end
end
