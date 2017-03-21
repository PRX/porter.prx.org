require IEx

defmodule BigQuery.Base do

  @timeout 30000
  @bq_base "https://www.googleapis.com/bigquery/v2"
  @options [{:timeout, @timeout}, {:recv_timeout, @timeout}]

  def get(path) do
    case get_token() do
      {:ok, token} ->
        request(:get, url_for(path), token)
      {:error, error} ->
        raise error
    end
  end

  def post(path, body) do
    case get_token() do
      {:ok, token} ->
        request(:post, url_for(path), token, body |> Map.put("timeoutMs", @timeout))
      {:error, error} ->
        raise error
    end
  end

  defp get_token do
    # TODO: cache this token
    BigQuery.Auth.get_token
  end

  defp url_for(path) do
    "#{@bq_base}/projects/#{Env.get(:bq_project_id)}/#{path}"
  end

  defp request(method, url, token) do
    apply(HTTPoison, method, [url, get_headers(token), @options])
    |> decode_response()
  end

  defp request(method, url, token, body) do
    {:ok, encoded_body} = Poison.encode(body)
    apply(HTTPoison, method, [url, encoded_body, get_headers(token, true), @options])
    |> decode_response()
  end

  defp get_headers(token, true), do: [{"Content-type", "application/json"} | get_headers(token)]

  defp get_headers(token), do: [{"Authorization", "Bearer #{token}"},
                               {"Accept", "application/json"}]

  defp decode_response({:ok, %HTTPoison.Response{status_code: 200, body: json}}) do
    JOSE.decode(json)
  end

  defp decode_response({:ok, %HTTPoison.Response{status_code: code, body: json}}) do
    raise JOSE.decode(json)["error"] || "Error: got #{code}"
  end

  defp decode_response({:error, error}) do
    raise HTTPoison.Error.message(error)
  end

end
