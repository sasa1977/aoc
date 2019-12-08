defmodule Aoc201908 do
  def run do
    IO.inspect(part1())
    IO.puts(part2())
  end

  defp part1() do
    layer = Enum.min_by(layers(), &digit_count(&1, 0))
    digit_count(layer, 1) * digit_count(layer, 2)
  end

  defp part2() do
    layers()
    |> final_image()
    |> image_to_printable_string()
  end

  defp final_image(layers) do
    Enum.reduce(
      layers,
      fn back_layer, front_layer ->
        front_layer
        |> Stream.zip(back_layer)
        |> Enum.map(&stack_pixels/1)
      end
    )
  end

  defp stack_pixels({front_pixel, back_pixel}),
    do: with(2 <- front_pixel, do: back_pixel)

  defp image_to_printable_string(image) do
    image
    |> Stream.map(&pixel_to_printable_char/1)
    |> Stream.chunk_every(25)
    |> Enum.intersperse(?\n)
  end

  defp pixel_to_printable_char(0), do: ?\s
  defp pixel_to_printable_char(1), do: ?*

  defp digit_count(layer, digit) do
    layer
    |> Stream.filter(&(&1 == digit))
    |> Enum.count()
  end

  defp layers() do
    Aoc.input_file(2019, 8)
    |> File.stream!([], 1)
    |> Stream.reject(&(&1 == "\n"))
    |> Stream.map(&String.to_integer/1)
    |> Stream.chunk_every(25 * 6, 25 * 6, :discard)
  end
end
