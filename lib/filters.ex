defmodule Filters do
  defmodule Parser do
    import NimbleParsec
    @debug? false

    def debug?, do: @debug?

    @whitespace_chars [?\s, ?\t, ?\n]

    @space ?\s
    @not_space not: @space
    @wildcard_char ?*
    @filter_separator_char ?;
    @alt_separator_char ?|
    @not_prop_separator not: @filter_separator_char
    @not_wildcard not: @wildcard_char
    @not_alt_separator not: @alt_separator_char

    @word @not_prop_separator ++ @not_wildcard ++ @not_space ++ @not_alt_separator ++ [not: ?\\]

    whitespace = ascii_string(@whitespace_chars, min: 1)
    optional_whitespace = optional(whitespace)

    left =
      ignore(optional_whitespace)
      |> choice([
        string("goal") |> replace("event:goal"),
        string("page") |> replace("event:page"),
        string("name") |> replace("event:name"),
        string("source") |> replace("visit:source"),
        string("country") |> replace("visit:country"),
        string("referrer") |> replace("visit:referrer"),
        string("utm_medium") |> replace("visit:utm_medium"),
        string("utm_source") |> replace("visit:utm_source"),
        string("utm_term") |> replace("visit:utm_term"),
        string("utm_content") |> replace("visit:utm_content"),
        string("utm_campaign") |> replace("visit:utm_campaign"),
        string("screen") |> replace("visit:screen"),
        string("browser_version") |> replace("visit:browser_version"),
        string("browser") |> replace("visit:browser"),
        string("os_version") |> replace("visit:os_version"),
        string("os") |> replace("visit:os"),
        string("device") |> replace("visit:device"),
        string("city") |> replace("visit:city"),
        string("region") |> replace("visit:region"),
        string("entry_page") |> replace("visit:entry_page"),
        string("exit_page") |> replace("visit:exit_page"),
        string("props:")
        |> replace("event:props:")
        |> ascii_string([?a..?z, ?A..?Z, ?0..9, ?_], min: 1)
        |> reduce({Enum, :join, [""]})
      ])
      |> label("key name")
      |> ignore(optional_whitespace)
      |> label("key")

    mid =
      ignore(optional_whitespace)
      |> choice([
        string("==") |> replace(:is),
        string("!=") |> replace(:is_not),
        string("~") |> replace(:contains),
        string("!~") |> replace(:does_not_contain)
      ])
      |> ignore(optional_whitespace)
      |> label("operator")

    wildcard =
      ascii_string([@wildcard_char], min: 1, max: 2)
      |> optional(whitespace)
      |> reduce({Enum, :join, [""]})
      |> tag(:wildcard)

    word =
      times(
        utf8_string(@word, min: 1)
        |> optional(whitespace)
        |> optional(string("\\|") |> replace("|") |> optional(whitespace))
        |> reduce({Enum, :join, [""]}),
        min: 1
      )

    valid_token = choice([word, wildcard])

    token =
      ignore(optional_whitespace)
      |> times(valid_token, min: 1)
      |> ignore(optional_whitespace)
      |> reduce({:mark_wildcards, []})

    alternative =
      token
      |> times(
        concat(
          ignore(ascii_char([@alt_separator_char])),
          token
        ),
        min: 1
      )
      |> wrap()

    exp =
      ignore(optional_whitespace)
      |> times(
        choice([
          alternative,
          token
        ]),
        min: 1
      )
      |> ignore(optional_whitespace)
      |> label("expression")

    filter =
      times(
        left
        |> concat(mid)
        |> concat(exp)
        |> ignore(optional(ascii_char([@filter_separator_char])))
        |> wrap(),
        min: 1
      )
      |> reduce({:reducer, []})

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

    defp mark_wildcards(args) do
      Enum.reduce(args, {:literal, ""}, fn
        {:wildcard, [wildcard]}, {_type, acc} ->
          {:wildcard, acc <> wildcard}

        literal, {type, acc} ->
          {type, acc <> literal}
      end)
    end

    defparsec(:filter, filter, debug: false)

    def parse_filters(input) do
      case filter(input) do
        {:ok, [filters], "", _, _, _} ->
          {:ok, filters}

        {:ok, [parsed], _failed_to_parse, _, _, _} ->
          {:ok, parsed}

        {:error, error, _, _, _, _} ->
          {:error, error}
      end
    end
  end
end
