defmodule Aoc201914 do
  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1, do: fuel_price(1)
  defp part2, do: binary_search(&(fuel_price(&1) <= 1_000_000_000_000))

  defp binary_search(criteria) do
    impossible = 1 |> Stream.iterate(&(&1 * 2)) |> Enum.find(&(not criteria.(&1)))

    {max_possible, _impossible} =
      Stream.iterate(
        {1, impossible},
        fn {possible, impossible} ->
          next = div(possible + impossible, 2)
          if criteria.(next), do: {next, impossible}, else: {possible, next}
        end
      )
      |> Enum.find(fn {possible, impossible} -> possible == impossible - 1 end)

    max_possible
  end

  defp fuel_price(amount) do
    {ore, _stock} = price("FUEL", amount, reactions(), %{})
    ore
  end

  defp price("ORE", required, _reactions, stock), do: {required, stock}
  defp price(_, 0, _reactions, stock), do: {0, stock}

  defp price(chemical, required, reactions, stock) do
    available = Map.get(stock, chemical, 0)
    taken_from_stock = min(available, required)
    remaining = max(available - taken_from_stock, 0)
    required = max(required - taken_from_stock, 0)
    stock = Map.put(stock, chemical, remaining)

    {produced, ingredients} = Map.fetch!(reactions, chemical)
    application_count = ceil(required / produced)

    surplus = application_count * produced - required
    stock = Map.update(stock, chemical, surplus, &(&1 + surplus))

    Enum.reduce(
      ingredients,
      {0, stock},
      fn {chemical, required}, {ore, stock} ->
        {required_ore, stock} = price(chemical, application_count * required, reactions, stock)
        {ore + required_ore, stock}
      end
    )
  end

  defp reactions() do
    Aoc.input_lines(__MODULE__)
    |> Stream.map(&parse_requirement/1)
    |> Map.new()
  end

  defp parse_requirement(string) do
    [requirements, output] = String.split(string, " => ")
    {output_name, output_quantity} = parse_chemical(output)
    requirements = Enum.map(String.split(requirements, ", "), &parse_chemical/1)
    {output_name, {output_quantity, requirements}}
  end

  defp parse_chemical(string) do
    %{"name" => name, "quantity" => quantity} = Regex.named_captures(~r/^(?<quantity>\d+) (?<name>.+)$/, string)
    {name, String.to_integer(quantity)}
  end
end
