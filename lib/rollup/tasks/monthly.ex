defmodule Mix.Tasks.Castle.Rollup.Monthly do
  use Castle.Rollup.Task

  @shortdoc "Rollup bigquery downloads by month"

  @interval "month"
  @table "monthly_downloads"
  @lock "lock.rollup.monthly_downloads"
  @default_count 10

  def run(args) do
    {:ok, _started} = Application.ensure_all_started(:castle)

    {opts, _, _} = OptionParser.parse args,
      switches: [lock: :boolean, date: :string, count: :integer],
      aliases: [l: :lock, d: :date, c: :count]

    do_rollup(opts, &rollup/1)
  end

  def rollup(rollup_log) do
    Logger.info "Rollup.MonthlyDownloads.#{rollup_log.date} querying"
    results = rollup_log.date |> Castle.Rollup.Query.MonthlyDownloads.from_hourly()
    Logger.info "Rollup.MonthlyDownloads.#{rollup_log.date} upserting #{length(results)}"
    Castle.MonthlyDownload.upsert_all(results)
    if is_past_month?(rollup_log.date) do
      set_complete(rollup_log)
      Logger.info "Rollup.MonthlyDownloads.#{rollup_log.date} complete"
    else
      set_incomplete(rollup_log)
      Logger.info "Rollup.MonthlyDownloads.#{rollup_log.date} incomplete"
    end
  end
end
