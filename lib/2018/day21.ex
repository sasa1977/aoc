defmodule Aoc201821 do
  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: Aoc.EnumHelper.first(terminating_inputs())
  defp part2(), do: Aoc.EnumHelper.last(terminating_inputs())

  defp terminating_inputs() do
    all_machine_states()
    # according to the input program, termination happens in instruction 28, if input (r0) == r1
    |> Stream.filter(&(&1.ip == 28))
    |> Stream.transform(MapSet.new(), fn machine, seen_states ->
      # if we're on the same instruction with the same registers, the machine will cycle, so we stop here
      if MapSet.member?(seen_states, machine.registers),
        do: {:halt, seen_states},
        else: {[machine], MapSet.put(seen_states, machine.registers)}
    end)
    |> Stream.map(&get_reg(&1, 1))
    |> Stream.uniq()
  end

  defp all_machine_states(), do: program() |> new_machine() |> Stream.iterate(&exec_next_instruction/1)

  defp program() do
    Aoc.input_lines(2018, 21)
    |> Stream.map(&String.replace(&1, ~r/;.*$/, ""))
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Enum.map(&parse_instruction/1)
  end

  defp parse_instruction(<<"#ip ", register>>), do: {:bind_ip, register - ?0}

  defp parse_instruction(<<op::binary-size(4), " ", args::binary>>) do
    args = String.replace(args, ~r/#.*/, "")
    {String.to_existing_atom(op), args |> String.split() |> Enum.map(&String.to_integer/1)}
  end

  defp new_machine([{:bind_ip, register} | instructions]) do
    %{
      ip: 0,
      ip_register: register,
      instructions: List.to_tuple(instructions),
      registers: 0..5 |> Stream.map(&{&1, 0}) |> Map.new()
    }
  end

  defp exec_next_instruction(%{ip: 18} = machine) do
    d = get_reg(machine, 3)
    f = get_reg(machine, 5)
    d = if d > f, do: d, else: div(f, 256)

    machine
    |> put_reg(2, 1)
    |> put_reg(3, d)
    |> put_reg(machine.ip_register, 25)
    |> update_ip()
  end

  defp exec_next_instruction(machine) do
    machine
    |> put_reg(machine.ip_register, machine.ip)
    |> exec(elem(machine.instructions, machine.ip))
    |> update_ip()
  end

  defp update_ip(machine), do: %{machine | ip: get_reg(machine, machine.ip_register) + 1}

  defp get_reg(machine, pos), do: Map.fetch!(machine.registers, pos)
  defp put_reg(machine, pos, value), do: %{machine | registers: Map.put(machine.registers, pos, value)}

  defp exec(machine, {instruction, [a, b, c]}), do: Map.fetch!(instructions(), instruction).(machine, a, b, c)

  defp instructions() do
    %{
      addr: &put_reg(&1, &4, get_reg(&1, &2) + get_reg(&1, &3)),
      addi: &put_reg(&1, &4, get_reg(&1, &2) + &3),
      mulr: &put_reg(&1, &4, get_reg(&1, &2) * get_reg(&1, &3)),
      muli: &put_reg(&1, &4, get_reg(&1, &2) * &3),
      banr: &put_reg(&1, &4, :erlang.band(get_reg(&1, &2), get_reg(&1, &3))),
      bani: &put_reg(&1, &4, :erlang.band(get_reg(&1, &2), &3)),
      borr: &put_reg(&1, &4, :erlang.bor(get_reg(&1, &2), get_reg(&1, &3))),
      bori: &put_reg(&1, &4, :erlang.bor(get_reg(&1, &2), &3)),
      gtir: &put_reg(&1, &4, if(&2 > get_reg(&1, &3), do: 1, else: 0)),
      gtri: &put_reg(&1, &4, if(get_reg(&1, &2) > &3, do: 1, else: 0)),
      gtrr: &put_reg(&1, &4, if(get_reg(&1, &2) > get_reg(&1, &3), do: 1, else: 0)),
      eqir: &put_reg(&1, &4, if(&2 == get_reg(&1, &3), do: 1, else: 0)),
      eqri: &put_reg(&1, &4, if(get_reg(&1, &2) == &3, do: 1, else: 0)),
      eqrr: &put_reg(&1, &4, if(get_reg(&1, &2) == get_reg(&1, &3), do: 1, else: 0)),
      setr: fn machine, reg_a, _b, reg_c -> put_reg(machine, reg_c, get_reg(machine, reg_a)) end,
      seti: fn machine, val, _b, reg_c -> put_reg(machine, reg_c, val) end
    }
  end
end
