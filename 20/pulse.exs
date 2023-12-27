defmodule Fifo do
  def new() do
    {[], []}
  end
  def push(fifo, item) do
    case fifo do
      {l, r} ->
        {[item | l], r}
    end
  end
  def split(fifo) do
    case fifo do
      {[], []} ->
        {nil, fifo}
      {l, []} ->
        case Enum.reverse(l) do
          [head | tail] ->
            {head, {[], tail}}
        end
      {l, [head | tail]} ->
        {head, {l, tail}}
    end
  end
  def size(fifo) do
    case fifo do
      {l, r} ->
        length(l) + length(r)
    end
  end
  def empty?(fifo) do
    case fifo do
      {[], []} -> true
      {_, _} -> false
    end
  end
end

defmodule Pulse do
  def parse_line(s) do
    case Regex.run(~r/^\s*([%&]?)(\w+)\s*->\s*([\w\s,]+)$/, s) do
      [_, op_str, label, dests_str] ->
        dests = String.split(dests_str, ",") |> Enum.map(&String.trim/1)
        op = case op_str do
               "%" -> :%
               "&" -> :&
               ""  -> :Y
             end
        {label, {op, dests}}
    end
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.map(&parse_line/1)
  end
  def accum_inputs(modules, inputs \\ %{}) do
    case modules do
      [] ->
        inputs
      [{label, {_op, dests}} | rest] ->
        inputs =
          Enum.reduce(dests, inputs, fn dest, map ->
            priors = Map.get(map, dest, [])
            Map.put(map, dest, [label | priors])
          end)
        accum_inputs(rest, inputs)
    end
  end
  def initial_state(modules) do
    inputs = accum_inputs(modules)
    Enum.map(modules, fn {label, {op, dests}} ->
      case op do
        :Y ->
          {label, {:Y, nil, dests}}
        :% ->
          {label, {:%, :off, dests}}
        :& ->
          prevs =
            Enum.reduce(Map.get(inputs, label, []), %{}, fn input, map ->
              Map.put(map, input, :lo)
            end)
          {label, {:&, prevs, dests}}
      end
    end) |>
      Map.new()
  end
  def initial_counts(modules) do
    button_counts = %{{"button", "broadcaster", :lo} => 0}
    Enum.reduce(modules, button_counts, fn {from, {_op, dests}}, counts ->
      Enum.reduce(dests, counts, fn to, m ->
        Map.put(m, {from, to, :lo}, 0) |> Map.put({from, to, :hi}, 0)
      end)
    end)
  end
  def process_pulse({from, to, level}, state) do
    {op, mstate, dests} = Map.get(state, to, {:Y, nil, []})
    case op do
      :Y ->
        pulses = Enum.map(dests, fn dest -> {to, dest, level} end)
        {pulses, state}
      :% ->
        case level do
          :hi ->
            {[], state}
          :lo ->
            {nstate, out_level} =
              case mstate do
                :off -> {:on, :hi}
                :on -> {:off, :lo}
              end
            pulses = Enum.map(dests, fn dest -> {to, dest, out_level} end)
            {pulses, %{state | to => {:%, nstate, dests}}}
        end
      :& ->
        nstate = %{mstate | from => level}
        out_level = if Enum.all?(Map.values(nstate), fn l -> l == :hi end) do
          :lo
        else
          :hi
        end
        pulses = Enum.map(dests, fn dest -> {to, dest, out_level} end)
        {pulses, %{state | to => {:&, nstate, dests}}}
    end
  end
  def process_pulses(pulses, state, counts, trace \\ %{}) do
    if Fifo.empty?(pulses) do
      {state, counts}
    else
      {pulse, rest} = Fifo.split(pulses)
      counts = Map.update!(counts, pulse, fn c -> c + 1 end)
      if Map.has_key?(trace, pulse) do
        trace = Map.update!(trace, pulse, fn c -> c + 1 end)
        if (trace[pulse] == 0) do
          IO.inspect(trace)
        end
      end
      {new_pulses, state} = process_pulse(pulse, state)
      pulses = Enum.reduce(new_pulses, rest, fn pulse, fifo ->
        Fifo.push(fifo, pulse)
      end)
      process_pulses(pulses, state, counts, trace)
    end
  end
  def push_button(state, counts, reps \\ 1, trace \\ %{}) do
    if reps <= 0 do
      {state, counts}
    else
      pulses = Fifo.push(Fifo.new(), {"button", "broadcaster", :lo})
      {state, counts} = process_pulses(pulses, state, counts, trace)
      push_button(state, counts, reps - 1, trace)
    end
  end
  def push_button_til(state, counts, pulse, reps \\ 0, trace \\ %{}) do
    {state1, counts1} = push_button(state, counts, 1, trace)
    reps = reps + 1
    if Map.get(counts1, pulse, 0) > 0 do
      {state1, counts1, reps}
    else
      push_button_til(state1, counts, pulse, reps, trace)
    end
  end
end

defmodule IntUtil do
  def gcd(a, b) do
    case {a, b} do
      {a, 0} -> a
      {0, b} -> b
      {a, b} -> gcd(b, rem(a, b))
    end
  end
  def lcm(a, b) do
    case {a, b} do
      {0, 0} -> 0
      {a, b} -> div(a * b, gcd(a, b))
    end
  end
end

case System.argv() do
  ["1", path] ->
    modules = Pulse.parse_file(path)
    state = Pulse.initial_state(modules)
    counts = Pulse.initial_counts(modules)
    {_state, counts} = Pulse.push_button(state, counts, 1000)
    sums = Enum.reduce(counts, %{lo: 0, hi: 0}, fn {{_from, _to, level}, c}, s ->
      Map.update!(s, level, fn prev -> prev + c end)
    end)
    IO.inspect(sums.hi * sums.lo)
  ["2", path] ->
    modules = Pulse.parse_file(path)
    inputs = Pulse.accum_inputs(modules)
    jz_inputs = inputs["jz"]
    state = Pulse.initial_state(modules)
    c0 = Pulse.initial_counts(modules)
    periods = Enum.map(jz_inputs, fn from ->
      pulse = {from, "jz", :hi}
      lo_pulse = {from, "jz", :lo}
      trace = %{pulse => -1, lo_pulse => 0}
      {state1, c1, reps} = Pulse.push_button_til(state, c0, pulse, 0, trace)
      {_, c2, reps2} = Pulse.push_button_til(state1, c0, pulse, 0, trace)
      IO.inspect({
        from, reps, c1[pulse], c1[lo_pulse], reps2, c2[pulse], c2[lo_pulse]})
      reps2
    end)
    Enum.reduce(periods, &IntUtil.lcm/2) |>
      IO.inspect()
  [] ->
    :ok
end
