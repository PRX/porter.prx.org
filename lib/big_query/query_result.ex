defmodule BigQuery.QueryResult do

  def from_response(data) do
    parse_rows(data["rows"], data["schema"]["fields"])
  end

  defp parse_rows([row | rest], schema) do
    [
      row["f"] |> parse_columns(schema) |> Enum.into(%{})
    ] ++ parse_rows(rest, schema)
  end

  defp parse_rows([], _schema), do: []

  defp parse_columns([column | rest], [%{"name" => name, "type" => type} | schema]) do
    [{
      String.to_atom(name),
      Map.get(column, "v") |> parse_value(type)
    }] ++ parse_columns(rest, schema)
  end

  defp parse_columns([], []), do: []

  defp parse_value(value, type) do
    case {type, value} do
      {"STRING", _} ->
        value
      {"BOOLEAN", "true"} ->
        true
      {"BOOLEAN", _} ->
        false
      {"INTEGER", _} ->
        String.to_integer(value)
      {"TIMESTAMP", _} ->
        {:ok, dtim} = String.to_float(value) |> round |> div(1000) |> DateTime.from_unix
        dtim
    end
  end

end
