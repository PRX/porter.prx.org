defmodule Castle.RollupLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @buffer_seconds 300
  @beginning_of_time ~D[2017-04-01]
  def beginning_of_time, do: @beginning_of_time

  schema "rollup_logs" do
    field :table_name, :string
    field :date, :date
    field :complete, :boolean, default: false
    timestamps()
  end

  def changeset(rollup_log, attrs) do
    rollup_log
    |> cast(attrs, [:table_name, :date, :complete])
    |> validate_required([:table_name, :date, :complete])
  end

  def upsert!(log) do
    conflict = [set: [updated_at: Timex.now(), complete: log.complete]]
    target = [:table_name, :date]
    Castle.Repo.insert!(log, on_conflict: conflict, conflict_target: target)
  end

  def query_from_time(rollup_log) do
    if rollup_log.updated_at && rollup_log.date == Timex.today do
      from = Timex.shift(rollup_log.updated_at, seconds: -@buffer_seconds)
      if from.day == rollup_log.date.day do
        Castle.Bucket.Hourly.floor(from)
      else
        Timex.to_datetime(rollup_log.date)
      end
    else
      Timex.to_datetime(rollup_log.date)
    end
  end

  def find_missing_days(tbl, lim), do: find_missing_days(tbl, lim, default_to_date())
  def find_missing_days(table_name, limit, to_date) do
    find_missing table_name, limit, """
      SELECT r.DATE as date
      FROM GENERATE_SERIES('#{date_str(to_date)}', '#{@beginning_of_time}', '-1 DAY'::INTERVAL) r
    """
  end

  def find_missing_months(tbl, lim), do: find_missing_months(tbl, lim, default_to_date())
  def find_missing_months(table_name, limit, to_date) do
    find_missing table_name, limit, """
      SELECT r.DATE as date
      FROM GENERATE_SERIES('#{date_str(to_date, :month)}', '#{@beginning_of_time}', '-1 MONTH'::INTERVAL) r
    """
  end

  defp find_missing(table_name, limit, range_sql) do
    dates = find_missing_dates(table_name, limit, range_sql)

    existing = Castle.Repo.all(from l in Castle.RollupLog,
      where: l.table_name == ^table_name and l.date in ^dates)

    Enum.map dates, fn(date) ->
      case Enum.find(existing, &(&1.date == date)) do
        nil -> %Castle.RollupLog{table_name: table_name, date: date}
        data -> data
      end
    end
  end

  defp find_missing_dates(table_name, limit, range_sql) do
    query = """
      SELECT range.date FROM (#{range_sql}) as range
      WHERE range.date NOT IN
        (SELECT date FROM rollup_logs WHERE table_name = $1 AND complete = true)
      ORDER BY range.date DESC limit $2
      """ |> String.replace("\n", " ")
    {:ok, result} = Ecto.Adapters.SQL.query(Castle.Repo, query, [table_name, limit])
    Enum.map result.rows, fn(row) ->
      {:ok, date} = Date.from_erl(hd(row))
      date
    end
  end

  defp default_to_date do
    Timex.now |> Timex.shift(seconds: -@buffer_seconds)
  end

  defp date_str("" <> date, :month), do: date
  defp date_str(date, :month), do: Timex.beginning_of_month(date) |> date_str()
  defp date_str("" <> date), do: date
  defp date_str(date) do
    {:ok, date_str} = Timex.format(date, "{YYYY}-{0M}-{0D}")
    date_str
  end
end
