defmodule Aoc201914 do
  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1, do: fuel_price(1)
  defp part2, do: binary_search(&(fuel_price(&1) <= 1_000_000_000_000))

  defp binary_search(criteria) do
    Stream.iterate(
      %{possible: 1, impossible: some_impossible(criteria)},
      fn result ->
        next = div(result.possible + result.impossible, 2)
        kind = if criteria.(next), do: :possible, else: :impossible
        Map.put(result, kind, next)
      end
    )
    |> Enum.find(&(&1.possible == &1.impossible - 1))
    |> Map.fetch!(:possible)
  end

  defp some_impossible(criteria), do: Enum.find(powers_of_two(), &(not criteria.(&1)))
  defp powers_of_two, do: Stream.iterate(1, &(&1 * 2))

  defp fuel_price(amount) do
    {price, _stock} = price({"FUEL", amount}, %{}, reactions())
    price
  end

  defp price({"ORE", amount}, stock, _reactions), do: {amount, stock}
  defp price({_chemical, 0}, stock, _reactions), do: {0, stock}

  defp price({chemical, amount}, stock, reactions) do
    {amount, stock} = take_from_stock(stock, chemical, amount)
    {produced, ingredients} = formula(reactions, chemical, amount)
    {prices, stock} = Enum.map_reduce(ingredients, stock, &price(&1, &2, reactions))
    {Enum.sum(prices), add_to_stock(stock, chemical, produced - amount)}
  end

  defp formula(reactions, chemical, amount) do
    {produced, ingredients} = Map.fetch!(reactions, chemical)
    num_applications = div(amount + produced - 1, produced)
    ingredients = Enum.map(ingredients, fn {chemical, quantity} -> {chemical, num_applications * quantity} end)
    {produced * num_applications, ingredients}
  end

  defp take_from_stock(stock, chemical, amount) do
    available = Map.get(stock, chemical, 0)
    taken = min(available, amount)
    {amount - taken, add_to_stock(stock, chemical, -taken)}
  end

  defp add_to_stock(stock, chemical, amount),
    do: Map.update(stock, chemical, amount, &(&1 + amount))

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
