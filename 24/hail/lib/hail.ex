defmodule Hail do
  @moduledoc """
  Documentation for `Hail`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Hail.hello()
      :world

  """
  def hello do
    :world
  end
    def parse_vec(s) do
    String.split(s, ",") |> Enum.map(fn ss ->
      String.trim(ss) |> String.to_integer()
    end)
  end
  def parse_line(s) do
    [pstr, vstr] = String.split(s, "@")
    [x, y, z] = parse_vec(pstr)
    [vx, vy, vz] = parse_vec(vstr)
    {[x, y, z], [vx, vy, vz]}
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.map(&parse_line/1)
  end
  def intersect_2d_traces({p1, v1}, {p2, v2}) do
    [x1, y1 | _] = p1
    [r1, s1 | _] = v1
    [x2, y2 | _] = p2
    [r2, s2 | _] = v2
    denominator = r1 * s2 - s1 * r2
    if (denominator == 0) do  # Parallel
      nil
    else
      q1 = y1 * (x1 + r1) - x1 * (y1 + s1)
      q2 = x2 * (y2 + s2) - y2 * (x2 + r2)
      xnum = r2 * q1 + r1 * q2
      ynum = s2 * q1 + s1 * q2
      xi = xnum / denominator
      yi = ynum / denominator
      t1 = if (r1 == 0) do
        (yi - y1) / s1
      else
      (xi - x1) / r1
      end
      t2 = if (r2 == 0) do
        (yi - y2) / s2
      else
      (xi - x2) / r2
      end
      {xi, yi, t1, t2}
    end
  end
  def intersect_all(rays, acc \\ []) do
    case rays do
      [] ->
        Enum.reverse(acc)
      [ray1 | rest] ->
        intersections =
          Enum.map(rest, fn ray2 -> intersect_2d_traces(ray1, ray2) end)
        intersect_all(rest, [intersections | acc])
    end
  end
  def count_intersections(rays, cmin, cmax) do
    intersections = intersect_all(rays) |> List.flatten()
    Enum.filter(intersections, fn isx ->
      case isx do
        nil ->
          false
        {x, y, t1, t2} ->
        (t1 >= 0 and t2 >= 0 and x >= cmin and x <= cmax and
          y >= cmin and y <= cmax)
      end
    end) |>
      Enum.count()
  end
  def matrix_eqn4(ray1, ray2) do
    {[x1, y1, _], [u1, v1, _]} = ray1
    {[x2, y2, _], [u2, v2, _]} = ray2
    x0c = v2 - v1
    y0c = u1 - u2
    u0c = y1 - y2
    v0c = x2 - x1
    rhs = x2 * v2 - x1 * v1 + y1 * u1 - y2 * u2
    {[x0c, y0c, u0c, v0c], rhs}
  end
  def matrix_eqn2(x0, u0, ray) do
    {[x1, _, z1], [u1, _, w1]} = ray
    z0c = u1 - u0
    w0c = x0 - x1
    rhs = w1 * (x0 - x1) + z1 * (u1 - u0)
    {[z0c, w0c], rhs}
  end
  def vdot(v1, v2) do
    Enum.zip_reduce(v1, v2, 0, fn x1, x2, acc -> acc + x1 * x2 end)
  end
  def vadd(v1, v2) do
    Enum.zip_with(v1, v2, fn x1, x2 -> x1 + x2 end)
  end
  def solve_xy_uv(rays) do
    raysample = Enum.shuffle(rays) |> Enum.take(5)
    {matrix, rhs} = Enum.chunk_every(raysample, 2, 1, :discard) |>
      Enum.reduce({[], []}, fn [ray1, ray2], {mm, rhs} ->
        {row, rhsv} = matrix_eqn4(ray1, ray2)
        {[row | mm], [[rhsv] | rhs]}
      end)
    inv_matrix = Gauss.mat_inv(matrix)
    [[x0], [y0], [u0], [v0]] = Gauss.mat_mult(inv_matrix, rhs)
    x0 = Ratio.trunc(x0)
    y0 = Ratio.trunc(y0)
    u0 = Ratio.trunc(u0)
    v0 = Ratio.trunc(v0)
    soln = {[x0, y0], [u0, v0]}
    checks = Enum.map(raysample, fn ray ->
      case intersect_2d_traces(soln, ray) do
        nil ->
          false
        {xi, yi, t1, t2} ->
          xi >= 0 and yi >= 0 and t1 >= 0 and t2 >= 0
      end
    end)
    if Enum.all?(checks) do
      soln
    else
      IO.puts("Failed attempt xy_uv: #{x0} #{y0} #{u0} #{v0} Retrying...")
      IO.puts("4x4 coefficient matrix:")
      IO.inspect(matrix)
      IO.puts("Inverse:")
      IO.inspect(inv_matrix)
      solve_xy_uv(rays)
    end
  end
  def solve_xyz_uvw(rays) do
    {[x0, y0], [u0, v0]} = solve_xy_uv(rays)
    [ray1, ray2] = Enum.shuffle(rays) |> Enum.take(2)
    {row1, rhs1} = matrix_eqn2(x0, u0, ray1)
    {row2, rhs2} = matrix_eqn2(x0, u0, ray2)
    matrix = [row1, row2]
    rhs = [[rhs1], [rhs2]]
    [[a, b], [c, d]] = matrix
    [[e], [f]] = rhs
    detm = a * d - b * c
    numz0 = e * d - b * f
    numw0 = a * f - e * c
    z0 = Ratio.trunc(Ratio.new(numz0, detm))
    w0 = Ratio.trunc(Ratio.new(numw0, detm))
    soln = {[x0, y0, z0], [u0, v0, w0]}
    mds = solution_distances(soln, rays)
    md_avg = Enum.sum(mds) / Enum.count(mds)
    limit = 1.0E-14 * (abs(x0) + abs(y0) + abs(z0))
    if md_avg > limit do
      IO.puts("... Retrying solve_xyz_uvw md_avg = #{md_avg} ...")
      IO.inspect(soln)
      IO.puts("Matrix:")
      IO.inspect(matrix)
      IO.puts("RHS:")
      IO.inspect(rhs)
      solve_xyz_uvw(rays)
    else
      IO.puts("Successful return of solve_xyz_uvw md_avg = #{md_avg}")
      {[x0, y0, z0], [u0, v0, w0]}
    end
  end
  def min_distance(ray1, ray2) do
    {[x1, y1, z1], [u1, v1, w1]} = ray1
    {[x2, y2, z2], [u2, v2, w2]} = ray2
    dx = [x2 - x1, y2 - y1, z2 - z1]
    dv = [u2 - u1, v2 - v1, w2 - w1]
    dxdv = vdot(dx, dv)
    dx2 = vdot(dx, dx)
    dv2 = vdot(dv, dv)
    if (dxdv > 0 or dv2 == 0) do
      dx2
    else
      num = dx2 * dv2 - dxdv * dxdv
      :math.sqrt(num / dv2)
    end
  end
  def optimize_md(soln, rays) do
    deltas = for dx <- -15..15, dy <- -15..15, dz <- -15..15, do: [dx, dy, dz]
    {p, v} = soln
    {pp_best, md_avg} =
      Enum.map(deltas, fn delta ->
        pp = vadd(p, delta)
        mds = solution_distances({pp, v}, rays)
        md_avg = Enum.sum(mds) / Enum.count(mds)
        {pp, md_avg}
      end) |>
      Enum.min_by(fn {_, md_avg} -> md_avg end)
    {{pp_best, v}, md_avg}
  end
  def solution_distances(ray0, rays) do
    Enum.map(rays, fn ray -> min_distance(ray0, ray) end)
  end
end
