defmodule Aoc201813 do
  def run() do
    part1()
    part2()
  end

  defp part1() do
    %{crashes: [{y, x}]} = all_ticks() |> Stream.drop_while(&Enum.empty?(&1.crashes)) |> Enum.at(0)
    IO.puts("#{x},#{y}")
  end

  defp part2() do
    %{carts: carts} = all_ticks() |> Stream.drop_while(&(Map.size(&1.carts) > 1)) |> Enum.at(0)
    [{{y, x}, _cart}] = Enum.to_list(carts)
    IO.puts("#{x},#{y}")
  end

  defp all_ticks(), do: Stream.iterate(initial_state(), &tick/1)

  defp tick(state) do
    state.carts
    |> Stream.map(fn {position, _cart} -> position end)
    |> Enum.sort()
    |> Enum.reduce(state, &move_cart(&2, &1))
  end

  defp move_cart(state, position) do
    case Map.fetch(state.carts, position) do
      :error ->
        state

      {:ok, cart} ->
        state = update_in(state.carts, &Map.delete(&1, cart.position))
        cart = shift_cart(cart)
        cart = turn_cart(cart, road_element(state, cart.position))

        case Map.pop(state.carts, cart.position) do
          {nil, _} -> put_in(state.carts[cart.position], cart)
          {_other_cart, remaining_carts} -> %{state | crashes: [cart.position | state.crashes], carts: remaining_carts}
        end
    end
  end

  defp road_element(state, {y, x}), do: state.map |> elem(y) |> elem(x)

  defp shift_cart(cart), do: update_in(cart.position, &new_position(cart.heading, &1))

  defp new_position(:up, position), do: up(position)
  defp new_position(:down, position), do: down(position)
  defp new_position(:left, position), do: left(position)
  defp new_position(:right, position), do: right(position)

  defp up({y, x}), do: {y - 1, x}
  defp down({y, x}), do: {y + 1, x}
  defp left({y, x}), do: {y, x - 1}
  defp right({y, x}), do: {y, x + 1}

  defp turn_cart(cart, straight) when straight in [:horizontal, :vertical], do: cart

  defp turn_cart(cart, :intersection) do
    turn = Map.fetch!(%{0 => :left, 1 => :straight, 2 => :right}, rem(cart.turns, 3))
    %{cart | heading: new_heading(cart.heading, turn), turns: cart.turns + 1}
  end

  defp turn_cart(cart, {:curve, turn_map}), do: %{cart | heading: Map.fetch!(turn_map, cart.heading)}

  defp new_heading(heading, :straight), do: heading
  defp new_heading(:left, :left), do: :down
  defp new_heading(:left, :right), do: :up
  defp new_heading(:right, :left), do: :up
  defp new_heading(:right, :right), do: :down
  defp new_heading(:up, :left), do: :left
  defp new_heading(:up, :right), do: :right
  defp new_heading(:down, :left), do: :right
  defp new_heading(:down, :right), do: :left

  defp initial_state() do
    input_map = input_map()
    max_x = input_map |> Stream.map(fn {{_y, x}, _char} -> x end) |> Enum.max()
    max_y = input_map |> Stream.map(fn {{y, _x}, _char} -> y end) |> Enum.max()
    map = 0..max_y |> Enum.map(&parse_row(&1, max_x, input_map)) |> List.to_tuple()
    carts = input_map |> Stream.filter(fn {_position, cart} -> cart in [?<, ?>, ?^, ?v] end) |> Enum.map(&parse_cart/1)
    %{map: map, carts: Map.new(Enum.map(carts, &{&1.position, &1})), crashes: []}
  end

  defp input_map() do
    Aoc.input_file(2018, 13)
    |> File.stream!()
    |> Stream.map(&String.trim_trailing/1)
    |> Stream.map(&to_charlist/1)
    |> Stream.with_index()
    |> Stream.flat_map(&chars/1)
    |> Map.new()
  end

  defp chars({line, y}), do: line |> Stream.with_index() |> Stream.map(fn {char, x} -> {{y, x}, char} end)

  defp parse_row(y, max_x, input_map) do
    0..max_x
    |> Stream.map(&{y, &1})
    |> Enum.map(&road_symbol(input_map, &1, Map.get(input_map, &1, ?\s)))
    |> List.to_tuple()
  end

  defp road_symbol(_input_map, _position, ?\s), do: nil
  defp road_symbol(_input_map, _position, ?|), do: :vertical
  defp road_symbol(_input_map, _position, ?-), do: :horizontal
  defp road_symbol(_input_map, _position, ?+), do: :intersection
  defp road_symbol(_input_map, _position, ?/), do: {:curve, %{up: :right, left: :down, down: :left, right: :up}}
  defp road_symbol(_input_map, _position, ?\\), do: {:curve, %{up: :left, left: :up, down: :right, right: :down}}

  defp road_symbol(input_map, position, cart) when cart in [?<, ?>, ?^, ?v] do
    up? = Map.get(input_map, up(position), ?\s) in [?|, ?+, ?\\, ?/]
    down? = Map.get(input_map, down(position), ?\s) in [?|, ?+, ?\\, ?/]
    left? = Map.get(input_map, left(position), ?\s) in [?-, ?+, ?\\, ?/]
    right? = Map.get(input_map, right(position), ?\s) in [?-, ?+, ?\\, ?/]

    case {up?, down?, left?, right?} do
      {true, true, true, true} -> :intersection
      {true, true, _left?, _right?} -> :vertical
      {_up?, _down?, true, true} -> :horizontal
    end
  end

  defp parse_cart({position, ?<}), do: new_cart(position, :left)
  defp parse_cart({position, ?>}), do: new_cart(position, :right)
  defp parse_cart({position, ?^}), do: new_cart(position, :up)
  defp parse_cart({position, ?v}), do: new_cart(position, :down)

  defp new_cart(position, heading), do: %{position: position, heading: heading, turns: 0}
end
