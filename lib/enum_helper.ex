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

  @doc "Returns the first element of the given non-empty enumerable."
  @spec first_element(Enumerable.t()) :: value :: any
  def first_element(enumerable), do: enumerable |> Enum.take(1) |> hd()

  @doc "Returns the last element of the given non-empty enumerable."
  @spec last_element(Enumerable.t()) :: value :: any
  def last_element(enumerable) do
    {:ok, value} =
      Enum.reduce(enumerable, {:error, :empty}, fn value, _previous -> {:ok, value} end)

    value
  end
end
