defmodule Castle.Bucket.Weekly do
  @behaviour Castle.Bucket

  def name, do: "WEEK"

  def rollup, do: "week"

  def is_a?(param), do: Enum.member?(["1w", "WEEK"], param)

  def floor(time) do
    Timex.beginning_of_week(time, 7)
  end

  def ceiling(time) do
    if Timex.compare(__MODULE__.floor(time), time) == 0 do
      time
    else
      Timex.beginning_of_week(time, 7) |> Timex.shift(weeks: 1)
    end
  end

  def next(time) do
    Timex.shift(time, seconds: 1) |> ceiling()
  end

  def range(from, to) do
    range(__MODULE__.floor(from), ceiling(to), [])
  end
  def range(from, to, acc) do
    if Timex.compare(from, to) >= 0 do
      acc
    else
      next(from) |> range(to, acc ++ [from])
    end
  end

  def count_range(from, to) do
    start = __MODULE__.floor(from) |> Timex.to_unix()
    stop = ceiling(to) |> Timex.to_unix()
    Float.ceil(max(stop - start, 0) / 604800) |> round
  end
end
