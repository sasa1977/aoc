defmodule Aoc201808 do
  def run() do
    numbers() |> license_number(&license1/1) |> IO.puts()
    numbers() |> license_number(&license2/1) |> IO.puts()
  end

  defp numbers() do
    Aoc.input_file(2018, 8)
    |> File.read!()
    |> String.split()
    |> Enum.map(&String.to_integer/1)
  end

  defp license1(node), do: node.metas |> Stream.concat(node.children) |> Enum.sum()

  defp license2(%{children: []} = node), do: Enum.sum(node.metas)
  defp license2(node), do: Enum.reduce(node.metas, 0, &(Enum.at(node.children, &1 - 1, 0) + &2))

  defp license_number(numbers, license_strategy) do
    {license_number, _remaining_numbers = []} = next_node(numbers, license_strategy)
    license_number
  end

  defp next_node(numbers, create_node_fun) do
    [num_children, num_metas | numbers] = numbers
    {children, numbers} = next_nodes(numbers, num_children, create_node_fun)
    {metas, numbers} = Enum.split(numbers, num_metas)
    {create_node_fun.(%{metas: metas, children: children}), numbers}
  end

  defp next_nodes(numbers, num_children, create_node_fun) do
    {reversed_children, numbers} =
      Enum.reduce(
        Stream.take(Stream.cycle([nil]), num_children),
        {[], numbers},
        fn _, {children, numbers} ->
          {child, numbers} = next_node(numbers, create_node_fun)
          {[child | children], numbers}
        end
      )

    {Enum.reverse(reversed_children), numbers}
  end
end
