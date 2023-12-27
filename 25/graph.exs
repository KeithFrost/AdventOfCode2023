defmodule Graph do
  def parse_line(s) do
    case Regex.run(~r/^\s*(\w+)\s*:(.*)$/, s) do
      [_, v0, vs_str] ->
        vs = String.split(vs_str)
        Enum.map(vs, fn v -> {v0, v} end)
    end
  end
  def parse_file(path) do
    File.stream!(path) |>
      Enum.flat_map(&parse_line/1)
  end
  def random_cut(edges, gmap \\ %{}) do
    gset = Enum.reduce(edges, MapSet.new(), fn {v0, v1}, gs ->
      g0 = Map.get(gmap, v0, v0)
      g1 = Map.get(gmap, v1, v1)
      MapSet.put(gs, g0) |> MapSet.put(g1)
    end)
    if MapSet.size(gset) == 2 do
      {edges, gset}
    else
      {v0, v1} = Enum.random(edges)
      g0 = Map.get(gmap, v0, v0)
      g1 = Map.get(gmap, v1, v1)
      gm = "#{g0}:#{g1}"
      gm_nodes = String.split(gm, ":")
      gmap = Enum.reduce(gm_nodes, gmap, fn v, acc -> Map.put(acc, v, gm) end)
      edges = Enum.filter(edges, fn {x, y} ->
        Map.get(gmap, x, x) != gm or Map.get(gmap, y, y) != gm
      end)
      random_cut(edges, gmap)
    end
  end
  def smallest_cut(edges, reps) do
    {:ok, {es, gset}} =
      Task.async_stream(
        1..reps,
        fn _ -> random_cut(edges) end,
        timeout: 60000
      ) |>
      Enum.min_by(fn {:ok, {es, _gset}} -> length(es) end)
    {es, gset}
  end
  def cut_no_bigger(edges, max_size, reps \\ 0) do
    reps = reps + 1
    {es, gset} = smallest_cut(edges, 8)
    if length(es) > max_size do
      es_str = Enum.map(es, fn {v0, v1} -> "#{v0}:#{v1}" end) |>
        Enum.join(" ")
      IO.puts("#{reps} #{es_str}")
      cut_no_bigger(edges, max_size, reps)
    else
      {es, gset}
    end
  end
end



case System.argv() do
  [cut_size_str, path] ->
    cut_size = String.to_integer(cut_size_str)
    edges = Graph.parse_file(path)
    {cuts, gset} = Graph.cut_no_bigger(edges, cut_size)
    IO.inspect(cuts)
    IO.inspect(gset)
    prod = Enum.reduce(gset, 1, fn s, prod ->
      prod * length(String.split(s, ":"))
    end)
    IO.inspect(prod)
  [] ->
    :ok
end
