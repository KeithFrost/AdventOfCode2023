defmodule Rules do
  def parse_workflow(s) do
    case Regex.run(~r/^(\w+){(.+)}$/, s) do
      [_, label, rules_str] ->
        rule_strs = String.split(rules_str, ",")
        rules = Enum.map(rule_strs, fn rule_str ->
          case Regex.run(~r/^([xmas])([<>])(\d+):(\w+)$/, rule_str) do
            [_, var, op, num_str, dest] ->
              {{String.to_atom(var),
                String.to_atom(op),
                String.to_integer(num_str)},
               String.to_atom(dest)}
            nil ->
              if Regex.match?(~r/^\w+$/, rule_str) do
                {nil, String.to_atom(rule_str)}
              else
                nil
              end
          end
        end)
        {String.to_atom(label), rules}
      nil ->
        nil
    end
  end
  def parse_part(s) do
    case Regex.run(~r/^{x=(\d+),m=(\d+),a=(\d+),s=(\d+)}$/, s) do
      [_ | value_strs] ->
        values = Enum.map(value_strs, &String.to_integer/1)
        Enum.zip([:x, :m, :a, :s], values)
      nil ->
        nil
    end
  end
  def parse_line(s, state) do
    case state.parsing do
      :workflows ->
        workflow = parse_workflow(s)
        if workflow != nil do
          %{state | workflows: [workflow | state.workflows]}
        else
          %{state | parsing: :parts}
        end
      :parts ->
        part = parse_part(s)
        if part != nil do
          %{state | parts: [Map.new(part) | state.parts]}
        else
          state
        end
    end
  end
  def parse_file(path) do
    state = File.stream!(path) |> Enum.reduce(
      %{parsing: :workflows, workflows: [], parts: []},
      &parse_line/2)
    %{parts: Enum.reverse(state.parts), workflows: Map.new(state.workflows)}
  end
  def run_workflow(part, workflow) do
    case workflow do
      [{nil, label} | _] ->
        label
      [{{var, op, num}, label} | rest] ->
        case op do
          :> ->
            if part[var] > num do
              label
            else
              run_workflow(part, rest)
            end
          :< ->
            if part[var] < num do
              label
            else
              run_workflow(part, rest)
            end
        end
    end
  end
  def run_workflows(part, label, workflows) do
    workflow = Map.get(workflows, label)
    if workflow == nil do
      label
    else
      next_label = run_workflow(part, workflow)
      run_workflows(part, next_label, workflows)
    end
  end
  def sum_accepted_parts(state) do
    state.parts |>
      Enum.map(fn part ->
        {part, run_workflows(part, :in, state.workflows)}
      end) |>
      Enum.filter(fn {_, label} -> label == :A end) |>
      Enum.map(fn {part, :A} ->
        Enum.reduce(part, 0, fn {_var, value}, sum -> sum + value end)
      end) |>
      Enum.sum()
  end
  def analyze_workflows(cohorts, workflows, acc \\ []) do
    case cohorts do
      [] ->
        acc
      [{label, ranges} | rest] ->
        workflow = Map.get(workflows, label)
        if workflow == nil do
          analyze_workflows(rest, workflows, [{label, ranges} | acc])
        else
          new_cohorts = analyze_workflow(ranges, workflow)
          analyze_workflows(new_cohorts ++ rest, workflows, acc)
        end
    end
  end
  def analyze_workflow(ranges, workflow, acc \\ []) do
    case workflow do
      [{nil, label} | _] ->
        [{label, ranges} | acc]
      [{{var, op, num}, label} | rest] ->
        {vmin, vmax} = ranges[var]
        case op do
          :> ->
            cond do
              vmax <= num ->
                analyze_workflow(ranges, rest, acc)
              vmin > num ->
                [{label, ranges} | acc]
              true ->
                included = %{ranges | var => {num + 1, vmax}}
                excluded = %{ranges | var => {vmin, num}}
                analyze_workflow(excluded, rest, [{label, included} | acc])
            end
          :< ->
            cond do
              vmin >= num ->
                analyze_workflow(ranges, rest, acc)
              vmax < num ->
                [{label, ranges} | acc]
              true ->
                included = %{ranges | var => {vmin, num - 1}}
                excluded = %{ranges | var => {num, vmax}}
                analyze_workflow(excluded, rest, [{label, included} | acc])
            end
        end
    end
  end
  def count_accepted_combos(cohorts) do
    Enum.filter(cohorts, fn {label, _ranges} -> label == :A end) |>
      Enum.reduce(0, fn {:A, ranges}, sum ->
        sum + Enum.reduce(ranges, 1, fn {_var, {vmin, vmax}}, prod ->
          prod * (vmax - vmin + 1) end)
      end)
  end
end

case System.argv() do
  ["1", path] ->
    state = Rules.parse_file(path)
    IO.inspect(Rules.sum_accepted_parts(state))
  ["2", path] ->
    state = Rules.parse_file(path)
    range0 = {1, 4000}
    cohort0 = {:in, %{x: range0, m: range0, a: range0, s: range0}}
    cohorts = Rules.analyze_workflows([cohort0], state.workflows)
    IO.inspect(Rules.count_accepted_combos(cohorts))
  [] ->
    :ok
end
