defmodule Aoc201812 do
  def run() do
    part1()
    part2()
  end

  defp part1(), do: score(initial_state(), 20) |> IO.puts()
  defp part2(), do: score(initial_state(), 50_000_000) |> IO.puts()

  defp score(state, num_steps, cached_transitions \\ %{})

  defp score(state, 0, _cached_transitions), do: score(state)

  defp score(state, num_steps, cached_transitions) do
    case transition(cached_transitions, state.plants, num_steps) do
      {:cycle, cycle_steps, cycle_position_offset} ->
        num_cycles = div(num_steps, cycle_steps)
        new_position = state.position + cycle_position_offset * num_cycles
        next_state = %{state | position: new_position}
        score(next_state, num_steps - num_cycles * cycle_steps, cached_transitions)

      {plants, steps, position_offset} ->
        next_state = %{state | plants: plants, position: state.position + position_offset}
        score(next_state, num_steps - steps, cached_transitions)

      nil ->
        next_state = next_state(state)
        next_transition = {next_state.plants, next_state.position - state.position}
        cached_transitions = Map.put(cached_transitions, state.plants, next_transition)
        score(next_state, num_steps - 1, cached_transitions)
    end
  end

  defp transition(transitions, initial_plants, max_steps, steps \\ 0, plants \\ nil, offset \\ 0)

  defp transition(_transitions, _initial_plants, max_steps, max_steps, plants, offset),
    do: {plants, max_steps, offset}

  defp transition(transitions, initial_plants, max_steps, steps, plants, offset) do
    case Map.fetch(transitions, plants || initial_plants) do
      {:ok, {^initial_plants, next_offset}} ->
        {:cycle, steps + 1, offset + next_offset}

      {:ok, {next_plants, next_offset}} ->
        transition(transitions, initial_plants, max_steps, steps + 1, next_plants, offset + next_offset)

      :error ->
        if not is_nil(plants), do: {plants, steps, offset}, else: nil
    end
  end

  defp score(state) do
    state.plants
    |> to_charlist()
    |> Stream.with_index(state.position)
    |> Stream.filter(&match?({?#, _position}, &1))
    |> Stream.map(fn {?#, position} -> position end)
    |> Enum.sum()
  end

  defp next_state(state) do
    next_plants = to_string(transform_plants(state.plants, state.rules))
    pad_plants(%{state | plants: next_plants, position: state.position + 2})
  end

  defp transform_plants(plants, rules)

  defp transform_plants(<<pattern::binary-size(5), _rest::binary>> = plants, rules) do
    <<_, rest::binary>> = plants
    next_element = Map.get(rules, pattern, ".")
    [next_element | transform_plants(rest, rules)]
  end

  defp transform_plants(_other, _rules), do: ""

  defp pad_plants(state), do: state |> pad_leading_plants() |> pad_trailing_plants()

  defp pad_leading_plants(state) do
    %{"empty" => empty} = Regex.named_captures(~r/^(?<empty>\.*)/, state.plants)
    padding_length = max(0, 4 - String.length(empty))
    plants = to_string([List.duplicate(?., padding_length), state.plants])
    position = state.position - padding_length
    %{state | plants: plants, position: position}
  end

  defp pad_trailing_plants(state) do
    %{"empty" => empty} = Regex.named_captures(~r/(?<empty>\.*)$/, state.plants)
    padding_length = max(0, 4 - String.length(empty))
    %{state | plants: to_string([state.plants, List.duplicate(?., padding_length)])}
  end

  defp initial_state() do
    {initial_state, rules} = Enum.split(Aoc.input_lines(2018, 12), 2)
    pad_plants(%{position: 0, plants: parse_plants(initial_state), rules: parse_rules(rules)})
  end

  defp parse_plants(["initial state: " <> state, ""]), do: state
  defp parse_rules(rules), do: rules |> Stream.map(&parse_rule/1) |> Map.new()
  defp parse_rule(rule), do: rule |> String.split(" => ") |> List.to_tuple()
end
