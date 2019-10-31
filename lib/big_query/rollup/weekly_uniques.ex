defmodule BigQuery.Rollup.WeeklyUniques do
  alias BigQuery.Base.Query, as: Query
  use BigQuery.Rollup.Uniques

  def query(func), do: query(Timex.now, func)
  def query(dtim, func) do
    BigQuery.Rollup.for_day dtim, fn(end_at_day) ->

      start_day = Timex.beginning_of_week(end_at_day, :mon)
      end_day = Timex.beginning_of_day(end_at_day)

      {:ok, start_at_str} = Timex.format(start_day, "{YYYY}-{0M}-{0D}")
      {:ok, end_at_str} = Timex.format(end_day, "{YYYY}-{0M}-{0D}")

      Query.query_each %{start_at_str: start_at_str, end_at_str: end_at_str}, sql(), fn(rows) ->
        format_results(rows, start_day) |> func.()
      end
    end
  end

  defp format_results(rows, start_day) do
    start_day = Timex.beginning_of_day(start_day) |> Timex.to_date()

    Enum.map(rows, &(format_result(&1, start_day)))
  end

  defp format_result(row, start_day) do
    row
    |> Map.put(:week, start_day)
  end
end