defmodule Network do
  def parse_dirs(s) do
    case Regex.run(~r/^\s*([LR]+)\s*$/, s) do
      nil -> nil
      [_, dirs] -> to_charlist(dirs)
    end
  end
  def parse_node(s) do
    case Regex.run(~r/^\s*(\w+)\s*=\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)\s*$/, s) do
      nil -> nil
      [_, label, left, right] -> {label, {left, right}}
    end
  end
  def parse_line(s, state) do
    case state.parsing do
      :dirs ->
        dirs = parse_dirs(s)
        case dirs do
          nil -> state
          _ -> %{state | dirs: dirs, parsing: :nodes}
        end
      :nodes ->
        node = parse_node(s)
        case node do
          nil ->
            state
          {label, value} ->
            Map.update!(state, :nodes, fn(nodes) ->
              Map.put(nodes, label, value) end)
        end
    end
  end
  def parse_file(path) do
    File.stream!(path) |>
      Enum.reduce(%{parsing: :dirs, dirs: [], nodes: %{}}, &parse_line/2)
  end
  def move_node(dir, label, nodes) do
    {left, right} = nodes[label]
    case dir do
      ?L -> left
      ?R -> right
    end
  end

  def start_nodes(nodes) do
    Enum.filter(Map.keys(nodes), fn label ->
      String.last(label) == "A" end)
  end
  def endz(label) do
    String.last(label) == "Z"
  end

  def zlist(start, dirs, nodes) do
    Stream.with_index(dirs) |>
      Stream.cycle() |>
      Stream.transform({0, start, %{}, false}, fn({dir, index}, state) ->
        {offset, label, zm, done} = state
        if done do
          {:halt, nil}
        else
          node = move_node(dir, label, nodes)
          if endz(label) do
            done = Map.has_key?(zm, {index, label})
            {[{offset, index, label}],
             {offset + 1, node, Map.put(zm, {index, label}, offset), done}}
          else
            {[], {offset + 1, node, zm, false}}
          end
        end
      end) |>
      Enum.to_list()
  end
  def zmap(zlist) do
    {z_offset1, z_index, z_label} = List.last(zlist)
    {z_offset0, _, _} =
      Enum.find(zlist, fn {_, index, label} ->
        index == z_index and label == z_label end)
    {preloop, loop} =
      Enum.split_while(zlist, fn {o, _, _} -> o <= z_offset0 end)
    period = z_offset1 - z_offset0
    %{pre: preloop, loop: loop, period: period}
  end
  def zstream(zmap) do
    %{pre: preloop, loop: loop, period: period} = zmap
    loop_stream =
      Stream.cycle([loop]) |>
      Stream.with_index() |>
      Stream.flat_map(fn {looplist, rep} ->
        Enum.map(looplist, fn {offset, index, label} ->
          {offset + rep * period, index, label} end)
      end)
    Stream.concat(preloop, loop_stream)
  end

  # N.B. This will only be reasonably efficient when the periods of the
  # two zlists are of a roughly similar order of magnitude.  In particular,
  # one must not simply reduce the zlists of the input using this function.
  # Instead, merge pairs of zlists, then pairs of those merged zlists, etc.
  def zlist_merged(zlist1, zlist2) do
    zmap1 = zmap(zlist1)
    zmap2 = zmap(zlist2)
    period1 = zmap1.period
    period2 = zmap2.period
    {init1, _, _} = List.first(zmap1.pre)
    {init2, _, _} = List.first(zmap2.pre)
    max_offset = init1 + init2 + 2 * lcm(period1, period2)
    offset_map1 =
      zstream(zmap1) |>
      Enum.take_while(fn {o, _, _} -> o <= max_offset end) |>
      Enum.map(fn {o, i, l} -> {o, {i, l}} end) |>
      Map.new()
    zstream(zmap2) |>
      Stream.transform({%{}, false}, fn({o, i, l}, {zm, done}) ->
        if done or o > max_offset do
          {:halt, nil}
        else
          if Map.has_key?(offset_map1, o) do
            {_, l1} = offset_map1[o]
            label = l1 <> "," <> l
            done = Map.has_key?(zm, {i, label})
            {[{o, i, label}],
             {Map.put(zm, {i, label}, o), done}}
          else
            {[], {zm, false}}
          end
        end
      end) |>
      Enum.to_list()
  end

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
    %{dirs: dirs, nodes: nodes} = Network.parse_file(path)
    IO.inspect(List.first(Network.zlist("AAA", dirs, nodes)))
  ["2", path] ->
    %{dirs: dirs, nodes: nodes} = Network.parse_file(path)
    zlists = Enum.map(Network.start_nodes(nodes), fn start ->
      Network.zlist(start, dirs, nodes) end)
    Stream.unfold(zlists, fn zls ->
      case zls do
        [] ->
          nil
        [zl] ->
          {[zl], []}
        _ ->
          {zls,
           Enum.chunk_every(zls, 2) |>
             Enum.map(fn
               [zl1, zl2] -> Network.zlist_merged(zl1, zl2)
               [zl1] -> zl1
             end)}
      end
    end) |>
      Enum.to_list() |>
      List.last() |>
      List.first() |>
      List.first() |>
      IO.inspect()
  _ ->
    :ok
end
