defmodule BigQuery.TimestampRollups.Weekly do
  @behaviour BigQuery.TimestampRollup

  def name, do: "WEEK"

  def rollup, do: "TIMESTAMP_TRUNC(timestamp, WEEK)"

  def is_a?(param), do: Enum.member?(["1w", "WEEK"], param)

  def floor(time) do
    Timex.beginning_of_week(time, 7)
  end

  def ceiling(time) do
    if Timex.compare(floor(time), time) == 0 do
      time
    else
      Timex.end_of_week(time, 7) |> Timex.shift(microseconds: 1)
    end
  end

  def next(time) do
    Timex.shift(time, seconds: 1) |> ceiling()
  end

  def range(from, to) do
    range(floor(from), ceiling(to), [])
  end
  def range(from, to, acc) do
    if Timex.compare(from, to) >= 0 do
      acc
    else
      next(from) |> range(to, acc ++ [from])
    end
  end

  def count_range(from, to) do
    start = floor(from) |> Timex.to_unix()
    stop = ceiling(to) |> Timex.to_unix()
    Float.ceil(max(stop - start, 0) / 604800) |> round
  end
end
