defmodule Aoc.EnumHelper do
  @doc "Returns the frequency map of the given enumerable."
  @spec frequency_map(Enumerable.t()) :: %{(value :: any) => count :: non_neg_integer}
  def frequency_map(values) do
    Enum.reduce(
      values,
      %{},
      fn value, frequency_map -> Map.update(frequency_map, value, 1, &(&1 + 1)) end
    )
  end
end
