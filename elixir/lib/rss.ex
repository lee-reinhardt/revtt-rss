defmodule RevttRSS do

  @path System.user_home! <> "/.revtt-rss"

  def load_file(file_name) do
    "#{@path}/#{file_name}" |> File.read!
  end

  def load_config do
    "config.json" |> load_file |> Poison.Parser.parse!
  end

  def load_list(file_name) do
    file_name |> load_file |> String.split("\n") |> Enum.filter(fn(item) -> item != "" end)
  end

  def fetch do
    config  = load_config
    url     = "https://revolutiontt.me/rss.php?feed=dl&cat=#{config["categories"]}&passkey=#{config["passkey"]}"
    headers = [ {:Cookie, "pass=#{config["pass"]}; uid=#{config["uid"]}"} ]

    HTTPoison.get!(url, headers)
  end

  def parse(r) do
    Floki.find(r.body, "item")
  end

  def is_good(title, list) do
    List.foldl(list, false, fn (regex, matched) ->
      if matched, do: true, else: Regex.match?(~r/#{regex}/, title)
    end)
  end

  def is_bad(title, list) do
    List.foldl(list, false, fn (regex, matched) ->
      if matched, do: true, else: Regex.match?(~r/#{regex}/, title)
    end)
  end

  def in_history(title, list) do
    List.foldl(list, false, fn (regex, matched) ->
      if matched, do: true, else: Regex.match?(~r/#{regex}/, title)
    end)
  end

  def download(item) do
    config = load_config
    resp   = HTTPoison.get!(item.link)
    File.write!("#{config["save_dir"]}/#{item.title}.torrent", resp.body)
  end

  def add_to_history(item) do
    {:ok, file} = File.open("#{@path}/history.txt", [:append])
    IO.write(file, "\n#{item.title}")
    File.close(file)
  end

  def prune_history do
    # todo
  end

  def main(_args) do
    good    = load_list("good.txt")
    bad     = load_list("bad.txt")
    history = load_list("history.txt")

    fetch()
    |> parse()
    |> Enum.map(fn(xml) ->
      {"item", _, children} = xml
      children
    end)
    |> Enum.map(fn(item) ->
      {{_, _, title}, _} = List.keytake(item, "title", 0)
      {{_, _, link}, _}  = List.keytake(item, "link", 0)
      %{title: List.first(title), link: List.first(link)}
    end)
    |> Stream.filter(fn(item) -> is_good(item.title, good) end)
    |> Stream.filter(fn(item) -> not is_bad(item.title, bad) end)
    |> Stream.filter(fn(item) -> not in_history(item.title, history) end)
    |> Stream.map(fn(item) ->
      download(item)
      item
    end)
    |> Enum.each(fn(item) -> add_to_history(item) end)

    prune_history()
  end

end