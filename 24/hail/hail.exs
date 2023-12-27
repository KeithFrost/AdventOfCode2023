case System.argv() do
  ["1", min_str, max_str, path] ->
    cmin = String.to_integer(min_str)
    cmax = String.to_integer(max_str)
    rays = Hail.parse_file(path)
    interxs = Hail.count_intersections(rays, cmin, cmax)
    n = Enum.count(rays)
    IO.puts("#{interxs} / #{div(n * (n - 1), 2)}")
  ["2", path] ->
    rays = Hail.parse_file(path)
    soln = Hail.solve_xyz_uvw(rays)
    IO.inspect(soln)
    min_ds = Hail.solution_distances(soln, rays)
    solx = if (Enum.sum(min_ds) == 0.0) do
      soln
    else
      {solx, _} = Hail.optimize_md(soln, rays)
      solx
    end
    IO.inspect(solx)
    min_ds = Hail.solution_distances(solx, rays)
    IO.inspect(min_ds)
    {p0, _v0} = solx
    IO.inspect(Enum.sum(p0))
  [] ->
    :ok
end
