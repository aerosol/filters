defmodule Filters do
  defmodule Parser do
    import NimbleParsec
    @debug? false

    def debug?, do: @debug?

    @space ?\s
    @whitespace_chars [@space, ?\t, ?\n]
    @not_space not: @space
    @wildcard_char ?*
    @filter_separator_char ?;
    @alt_separator_char ?|
    @not_prop_separator not: @filter_separator_char
    @not_wildcard not: @wildcard_char
    @not_alt_separator not: @alt_separator_char

    @word @not_prop_separator ++ @not_wildcard ++ @not_space ++ @not_alt_separator ++ [not: ?\\]

    whitespace = ascii_string(@whitespace_chars, min: 1)

    ignore_alt_separator =
      ignore(
        optional(whitespace)
        |> ascii_char([@alt_separator_char])
        |> optional(whitespace)
      )

    wildcard_key =
      choice([
        string("page") |> replace("event:page"),
        string("entry_page") |> replace("visit:entry_page"),
        string("exit_page") |> replace("visit:exit_page"),
        string("goal") |> replace("event:goal"),
        string("utm_medium") |> replace("visit:utm_medium"),
        string("utm_source") |> replace("visit:utm_source"),
        string("utm_term") |> replace("visit:utm_term"),
        string("utm_content") |> replace("visit:utm_content"),
        string("utm_campaign") |> replace("visit:utm_campaign")
      ])

    literal_key =
      choice([
        string("name") |> replace("event:name"),
        string("source") |> replace("visit:source"),
        string("referrer") |> replace("visit:referrer"),
        string("screen") |> replace("visit:screen"),
        string("browser_version") |> replace("visit:browser_version"),
        string("browser") |> replace("visit:browser"),
        string("os_version") |> replace("visit:os_version"),
        string("os") |> replace("visit:os"),
        string("device") |> replace("visit:device"),
        string("city") |> replace("visit:city"),
        string("region") |> replace("visit:region"),
        string("props:")
        |> replace("event:props:")
        |> ascii_string([?a..?z, ?A..?Z, ?0..9, ?_], min: 1)
        |> reduce({Enum, :join, [""]})
      ])

    country_key = string("country") |> replace("visit:country")

    operator =
      choice([
        string("==") |> replace(:is),
        string("!=") |> replace(:is_not),
        string("~") |> replace(:contains),
        string("!~") |> replace(:does_not_contain)
      ])

    wildcard = ascii_string([?*], min: 1, max: 2)

    words =
      optional(whitespace)
      |> optional(wildcard)
      |> utf8_char(@word)
      |> optional(
        optional(whitespace)
        |> optional(string("\\|") |> replace("|"))
        |> optional(whitespace)
        |> utf8_char(@word)
      )
      |> optional(wildcard)

    token =
      ignore(optional(whitespace))
      |> times(words, min: 1)

    literal_token = token |> reduce({:unwrap, [[tag_wildcards?: false]]})

    wildcard_token = token |> reduce({:unwrap, [[tag_wildcards?: true]]})

    country_token =
      ascii_string([?A..?Z], 2) |> lookahead_not(utf8_char(@word)) |> unwrap_and_tag(:literal)

    literal_expression =
      times(
        choice([
          # list of tokens
          literal_token
          |> times(
            ignore_alt_separator
            |> concat(literal_token),
            min: 1
          )
          |> wrap(),
          # just the token
          literal_token
        ]),
        min: 1
      )
      |> ignore(optional(whitespace))

    wildcard_expression =
      times(
        choice([
          # list of tokens
          wildcard_token
          |> times(
            ignore_alt_separator
            |> concat(wildcard_token),
            min: 1
          )
          |> wrap(),
          # just the token
          wildcard_token
        ]),
        min: 1
      )
      |> ignore(optional(whitespace))

    country_expression =
      times(
        choice([
          # list of tokens
          country_token
          |> times(
            ignore_alt_separator
            |> concat(country_token),
            min: 1
          )
          |> wrap(),
          # just the token
          country_token
        ]),
        min: 1
      )
      |> ignore(optional(whitespace))

    literal_filter =
      literal_key
      |> concat(operator)
      |> concat(literal_expression)

    wildcard_filter =
      wildcard_key
      |> concat(operator)
      |> concat(wildcard_expression)

    country_filter =
      country_key
      |> concat(operator)
      |> concat(country_expression)

    filter = choice([literal_filter, wildcard_filter, country_filter]) |> label("filter")

    filters =
      times(
        filter
        |> ignore(optional(ascii_char([@filter_separator_char])))
        |> wrap(),
        min: 1
      )
      |> reduce({:reducer, []})

    defp unwrap(args, opts) do
      if opts[:tag_wildcards?] and ("**" in args or "*" in args) do
        {:wildcard, List.to_string(args)}
      else
        {:literal, List.to_string(args)}
      end
    end

    defp reducer(args) do
      if @debug?, do: IO.inspect(args, label: :reducer)

      Enum.reduce(args, [], fn
        ["event:goal" = goal_key, operator, mixed_goals], acc when is_list(mixed_goals) ->
          mapped =
            Enum.map(mixed_goals, fn
              {type, "Visit " <> expression} ->
                {"event:page", operator, alter_expression(goal_key, operator, {type, expression})}

              {type, expression} ->
                {goal_key, operator, alter_expression(goal_key, operator, {type, expression})}
            end)

          mapped ++ acc

        ["event:goal" = goal_key, operator, {type, "Visit " <> expression}], acc ->
          [
            {"event:page", operator, alter_expression(goal_key, operator, {type, expression})}
            | acc
          ]

        [key, operator, expression], acc when is_list(expression) ->
          [{key, operator, alter_expression(key, operator, expression)} | acc]

        [key, operator, expression], acc ->
          [{key, operator, alter_expression(key, operator, expression)} | acc]
      end)
      |> Enum.reverse()
    end

    defp alter_expression(_key, operator, expression)
         when operator in [:contains, :does_not_contain] and is_list(expression) do
      Enum.map(expression, &force_wildcard/1)
    end

    defp alter_expression(_key, operator, expression)
         when operator in [:contains, :does_not_contain] do
      force_wildcard(expression)
    end

    defp alter_expression(_key, _operator, expression) do
      expression
    end

    defp force_wildcard({:literal, literal}) do
      {:wildcard, "**" <> literal <> "**"}
    end

    defp force_wildcard({:wildcard, wildcard}) do
      {:wildcard, "**" <> String.replace(wildcard, "*", "") <> "**"}
    end

    defparsec(:filters, filters, debug: @debug?)
    defparsec(:literal_expression, literal_expression, debug: @debug?)
    defparsec(:wildcard_expression, wildcard_expression, debug: @debug?)

    def parse(input, parse_with \\ :filters) do
      case apply(__MODULE__, parse_with, [input]) do
        {:ok, [parsed], "", _, _, _} ->
          {:ok, parsed}

        {:ok, [_partially_parsed], failed_to_parse, _, _, n} ->
          {:error,
           "Error - failed to parse: #{failed_to_parse}. Stopped parsing at character #{n}"}

        {:error, error, _, _, _, n} ->
          {:error, "Error: #{error}. Stopped parsing at character #{n}"}
      end
    end
  end
end
