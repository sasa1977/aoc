defmodule Aoc201817 do
  defmodule Position do
    alias __MODULE__

    @enforce_keys [:x, :y]
    defstruct [:x, :y]

    def new(x, y), do: %Position{x: x, y: y}

    def left(pos), do: %Position{pos | x: pos.x - 1}
    def right(pos), do: %Position{pos | x: pos.x + 1}
    def down(pos), do: %Position{pos | y: pos.y + 1}
  end

  def run() do
    part1()
    part2()
  end

  defp part1(), do: expand_water() |> water_elements() |> Enum.count() |> IO.puts()
  defp part2(), do: expand_water() |> water_elements() |> Stream.filter(&(&1 == :still)) |> Enum.count() |> IO.puts()

  defp water_elements(state), do: state.map |> Map.values() |> Stream.filter(&(&1 in [:still, :flow]))

  defp expand_water() do
    clay = clay()
    {top, bottom} = clay |> Stream.map(& &1.y) |> Enum.min_max()

    initial_state = %{
      map: clay |> Stream.map(&{&1, :clay}) |> Map.new(),
      top: top,
      bottom: bottom,
      spring: Position.new(500, top - 1)
    }

    {_water_state, final_state} = expand_water(initial_state, Position.down(initial_state.spring))
    final_state
  end

  defp expand_water(state, pos) do
    case element_at(state, pos) do
      :flow -> {:flow, state}
      block when block in [:clay, :still] -> {:still, state}
      :sand -> place_water_on_sand(state, pos)
    end
  end

  defp place_water_on_sand(%{bottom: bottom} = state, %{y: bottom} = pos),
    do: {:flow, store_water_state(state, pos, :flow)}

  defp place_water_on_sand(state, pos) do
    # We'll first mark this element as still water. Later on we might figure out that it's flowing.
    # The water at the given pos is flowing if the down branch or any of left/right branches are flowing.
    state = store_water_state(state, pos, :still)

    case expand_water(state, Position.down(pos)) do
      {:flow, state} ->
        # If down branch is flowing, then water here is is flowing too, and we can't branch neither left nor right.
        {:flow, store_water_state(state, pos, :flow)}

      {:still, state} ->
        {left_water_state, state} = expand_water(state, Position.left(pos))
        {right_water_state, state} = expand_water(state, Position.right(pos))

        # If any branch is flowing, then this element and both branches are flowing too.
        water_state = if left_water_state == :flow or right_water_state == :flow, do: :flow, else: :still

        # Store this water state
        state = store_water_state(state, pos, water_state)

        # If this point is flowing, we need to update immediate left/right points too, because it's possible that
        # e.g. left side is still, while the right side is flowing (this example is in the challenge text).
        state =
          if water_state == :flow,
            do: state |> mark_flow(pos, &Position.left/1) |> mark_flow(pos, &Position.right/1),
            else: state

        {water_state, state}
    end
  end

  defp element_at(state, pos), do: Map.get(state.map, pos, :sand)

  def store_water_state(state, pos, water_state), do: put_in(state.map[pos], water_state)

  defp mark_flow(state, pos, fun) do
    fun.(pos)
    |> Stream.iterate(fun)
    |> Stream.take_while(&(element_at(state, &1) == :still))
    |> Enum.reduce(state, &store_water_state(&2, &1, :flow))
  end

  defp clay(), do: Aoc.input_lines(2018, 17) |> Stream.flat_map(&positions/1) |> MapSet.new()

  defp positions(line) do
    %{"value_dim" => value_dim, "value" => value, "range_dim" => range_dim, "from" => from, "to" => to} =
      Regex.named_captures(~r/(?<value_dim>[xy])=(?<value>\d+),\s*(?<range_dim>[xy])=(?<from>\d+)\.\.(?<to>\d+)$/, line)

    value = String.to_integer(value)

    String.to_integer(from)..String.to_integer(to)
    |> Stream.map(&%{value_dim => value, range_dim => &1})
    |> Stream.map(&Position.new(Map.fetch!(&1, "x"), Map.fetch!(&1, "y")))
  end
end
