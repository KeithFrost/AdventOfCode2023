defmodule Gauss do
  require Ratio
  # To avoid numerous problems caused by floating point errors, we choose to
  # solve some linear systems of equations using exact rational arithmetic.
  def mat_square_size(matrix) do
    n = length(matrix)
    if not Enum.all?(matrix, fn row -> length(row) == n end) do
      nil
    else
      n
    end
  end
  def mat_coerce_rational(matrix) do
    Enum.map(matrix, fn row ->
      Enum.map(row, fn v ->
        cond do
          Ratio.is_rational(v) -> v
          is_integer(v) -> Ratio.new(v)
          # Otherwise, fail horribly: better to know at once.
        end
      end)
    end)
  end
  def mat_transpose(matrix) do
    Enum.zip_with(matrix, fn col -> col end)
  end
  def vdot(v1, v2) do
    Enum.zip_reduce(v1, v2, Ratio.new(0), fn e1, e2, acc ->
      Ratio.add(acc, Ratio.mult(e1, e2))
    end)
  end
  def vsub(v1, v2) do
    Enum.zip_with(v1, v2, fn e1, e2 -> Ratio.sub(e1, e2) end)
  end
  def vadd(v1, v2) do
    Enum.zip_with(v1, v2, fn e1, e2 -> Ratio.add(e1, e2) end)
  end
  def vscale(v, scalar) do
    r = Ratio.new(scalar)
    Enum.map(v, fn e -> Ratio.mult(r, e) end)
  end
  def mat_mult(m1, m2) do
    m1r = mat_coerce_rational(m1)
    m2t = mat_transpose(mat_coerce_rational(m2))
    Enum.map(m1r, fn row1 ->
      Enum.map(m2t, fn col2 -> vdot(row1, col2) end)
    end)
  end
  def mat_ident(n) do
    Enum.map(1..n, fn i ->
      Enum.map(1..n, fn j ->
        if i == j do Ratio.new(1) else Ratio.new(0) end
      end)
    end)
  end
  def prefix_rows(rows, v) do
    Enum.map(rows, fn row -> [v | row] end)
  end
  def find_pivot(rows) do
    if rows == [] do
      0
    else
      {i, _max} =
        Enum.with_index(rows, fn row, i -> {i, List.first(row)} end) |>
        Enum.max_by(fn {_i, h} -> abs(Ratio.to_float(h)) end)
      i
    end
  end
  def swap_row(row, rows, i, acc \\ []) do
    case rows do
      [] ->
        Enum.reverse([row | acc])
      [row0 | rest] ->
        if i <= 0 do
          [row0 | Enum.reverse([row | acc])] ++ rest
        else
          swap_row(row, rest, i - 1, [row0 | acc])
        end
    end
  end
  def pivot(rows) do
    index = find_pivot(rows)
    if index == 0 do
      rows
    else
      case rows do
        [] ->
          []
        [row | rest] ->
          swap_row(row, rest, index - 1)
      end
    end
  end
  def mat_row_reduce(rows, pvt \\ true) do
    case rows do
      [] ->
        []
      _ ->
        [row | rest] = if pvt do
            pivot(rows)
          else
            rows
          end
        v = List.first(row)
        nrow = vscale(row, Ratio.div(Ratio.new(1), v))
        [_ | rrow] = nrow
        below = Enum.map(rest, fn [head | tail] ->
          vsub(tail, vscale(rrow, head))
        end)
        [nrow | prefix_rows(mat_row_reduce(below, pvt), Ratio.new(0))]
    end
  end
  def mat_cat_rows(matrix1, matrix2) do
    Enum.zip_with(matrix1, matrix2, fn row1, row2 -> row1 ++ row2 end)
  end
  def mat_split_rows(matrix, n) do
    {left, right} = Enum.reduce(matrix, {[], []}, fn row, {l, r} ->
      {lrow, rrow} = Enum.split(row, n)
      {[lrow | l], [rrow | r]}
    end)
    {Enum.reverse(left), Enum.reverse(right)}
  end
  def mat_reverse2(matrix) do
    Enum.map(matrix, &Enum.reverse/1) |> Enum.reverse()
  end
  def mat_inv(m) do
    n = mat_square_size(m)
    mr = mat_coerce_rational(m)
    mx = mat_ident(n)
    combined = mat_cat_rows(mr, mx)
    reduced = mat_row_reduce(combined)
    {rleft, rright} = mat_split_rows(reduced, n)
    recombined = mat_cat_rows(mat_reverse2(rleft), mat_reverse2(rright))
    reduced2 = mat_row_reduce(recombined, false)
    {_ident, rev2_inv} = mat_split_rows(reduced2, n)
    mat_reverse2(rev2_inv)
  end
end
