defmodule Aoc2018.Device do
  def from_file(file) do
    file
    |> File.stream!()
    |> Stream.map(&String.replace(&1, ~r/;.*$/, ""))
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Enum.map(&parse_instruction/1)
    |> new()
  end

  def all_states(device, opts \\ []),
    do: device |> Stream.iterate(&next_state(&1, opts)) |> Stream.take_while(&(not is_nil(&1)))

  def register(device, pos), do: Map.fetch!(device.registers, pos)
  def put_register(device, pos, value), do: %{device | registers: Map.put(device.registers, pos, value)}

  def set_next_instruction(device, pos), do: next_instruction(put_register(device, device.ip_register, pos - 1))

  defp parse_instruction(<<"#ip ", register>>), do: {:bind_ip, register - ?0}

  defp parse_instruction(<<op::binary-size(4), " ", args::binary>>) do
    args = String.replace(args, ~r/#.*/, "")
    {String.to_existing_atom(op), args |> String.split() |> Enum.map(&String.to_integer/1)}
  end

  defp new([{:bind_ip, register} | instructions]) do
    %{
      ip: 0,
      ip_register: register,
      instructions: List.to_tuple(instructions),
      registers: 0..5 |> Stream.map(&{&1, 0}) |> Map.new()
    }
  end

  defp next_state(%{ip: ip, instructions: instructions}, _opts) when ip < 0 or ip >= tuple_size(instructions), do: nil

  defp next_state(device, opts) do
    case Map.fetch(Keyword.get(opts, :optimize, %{}), device.ip) do
      :error -> exec_next_instruction(device)
      {:ok, optimized} -> optimized.(device)
    end
  end

  defp exec_next_instruction(device) do
    device
    |> put_register(device.ip_register, device.ip)
    |> exec(elem(device.instructions, device.ip))
    |> next_instruction()
  end

  defp next_instruction(device), do: %{device | ip: register(device, device.ip_register) + 1}

  defp exec(device, {instruction, [a, b, c]}), do: Map.fetch!(instructions(), instruction).(device, a, b, c)

  defp instructions() do
    %{
      addr: &put_register(&1, &4, register(&1, &2) + register(&1, &3)),
      addi: &put_register(&1, &4, register(&1, &2) + &3),
      mulr: &put_register(&1, &4, register(&1, &2) * register(&1, &3)),
      muli: &put_register(&1, &4, register(&1, &2) * &3),
      banr: &put_register(&1, &4, :erlang.band(register(&1, &2), register(&1, &3))),
      bani: &put_register(&1, &4, :erlang.band(register(&1, &2), &3)),
      borr: &put_register(&1, &4, :erlang.bor(register(&1, &2), register(&1, &3))),
      bori: &put_register(&1, &4, :erlang.bor(register(&1, &2), &3)),
      gtir: &put_register(&1, &4, if(&2 > register(&1, &3), do: 1, else: 0)),
      gtri: &put_register(&1, &4, if(register(&1, &2) > &3, do: 1, else: 0)),
      gtrr: &put_register(&1, &4, if(register(&1, &2) > register(&1, &3), do: 1, else: 0)),
      eqir: &put_register(&1, &4, if(&2 == register(&1, &3), do: 1, else: 0)),
      eqri: &put_register(&1, &4, if(register(&1, &2) == &3, do: 1, else: 0)),
      eqrr: &put_register(&1, &4, if(register(&1, &2) == register(&1, &3), do: 1, else: 0)),
      setr: fn device, reg_a, _b, reg_c -> put_register(device, reg_c, register(device, reg_a)) end,
      seti: fn device, val, _b, reg_c -> put_register(device, reg_c, val) end
    }
  end
end
