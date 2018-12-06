defmodule Aoc201804 do
  def run() do
    part1() |> IO.inspect()
    part2() |> IO.inspect()
  end

  defp part1(), do: best_guard_minute(&total_sleep_time/1)
  defp part2(), do: best_guard_minute(&most_asleep(&1).days)

  defp best_guard_minute(strategy) do
    guard = Enum.max_by(guards(), strategy)
    guard.id * most_asleep(guard).minute
  end

  defp guards() do
    ordered_events()
    |> group_by_watch()
    |> group_by_guard()
  end

  defp group_by_watch(ordered_events) do
    ordered_events
    |> Stream.concat([%{command: {:begin_shift, nil}}])
    |> Stream.transform(
      nil,
      fn
        %{command: {:begin_shift, guard_id}}, nil -> {[], new_guard(guard_id)}
        %{command: {:begin_shift, guard_id}}, guard -> {[guard], new_guard(guard_id)}
        %{command: :fall_asleep, minute: minute}, guard -> {[], fall_asleep(guard, minute)}
        %{command: :wake_up, minute: minute}, guard -> {[], wake_up(guard, minute)}
      end
    )
    |> Stream.reject(&Enum.empty?(&1.sleeps))
  end

  defp group_by_guard(watches) do
    watches
    |> Enum.group_by(& &1.id, & &1.sleeps)
    |> Stream.map(fn {guard_id, all_sleeps} -> new_guard(guard_id, Enum.concat(all_sleeps)) end)
  end

  defp new_guard(guard_id, sleeps \\ []), do: %{id: guard_id, sleeps: sleeps, asleep_at: nil}

  defp sleep_minutes(guard), do: Stream.concat(guard.sleeps)

  defp fall_asleep(guard, minute), do: %{guard | asleep_at: minute}

  defp wake_up(guard, minute),
    do: %{guard | sleeps: [guard.asleep_at..(minute - 1) | guard.sleeps], asleep_at: nil}

  defp total_sleep_time(guard), do: guard |> sleep_minutes() |> Enum.count()

  defp most_asleep(guard) do
    {minute, days} =
      guard
      |> sleep_minutes()
      |> Aoc.EnumHelper.frequencies()
      |> Enum.max_by(fn {_minute, days} -> days end)

    %{minute: minute, days: days}
  end

  defp ordered_events() do
    Aoc.input_lines(2018, 4)
    |> Enum.sort()
    |> Stream.map(&decode_event/1)
  end

  defp decode_event(event_string) do
    %{"minute" => minute, "command" => command} =
      Regex.named_captures(
        ~r/\[\d{4}-\d\d-\d\d \d\d:(?<minute>\d\d)\] (?<command>.*)/,
        event_string
      )

    %{minute: String.to_integer(minute), command: decode_command(command)}
  end

  defp decode_command("falls asleep"), do: :fall_asleep
  defp decode_command("wakes up"), do: :wake_up
  defp decode_command("Guard #" <> begin_shift_string), do: decode_begin_shift(begin_shift_string)

  defp decode_begin_shift(begin_shift_string) do
    {guard, " begins shift"} = Integer.parse(begin_shift_string)
    {:begin_shift, guard}
  end
end
