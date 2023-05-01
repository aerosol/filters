defmodule Filters do
  defmodule Parser do
    import NimbleParsec

    @whitespace_chars [?\s, ?\t, ?\n]

    @space ?\s
    @not_space not: @space
    @wildcard_char ?*
    @filter_separator_char ?;
    @alt_separator_char ?|
    @not_prop_separator not: @filter_separator_char
    @not_wildcard not: @wildcard_char
    @not_alt_separator not: @alt_separator_char

    @word @not_prop_separator ++ @not_wildcard ++ @not_alt_separator ++ @not_space

    whitespace = ascii_string(@whitespace_chars, min: 1)
    optional_whitespace = optional(whitespace)

    left =
      ignore(optional_whitespace)
      |> concat(ascii_string([?a..?z, ?:, ?_], min: 3) |> label("key name"))
      |> ignore(optional_whitespace)
      |> label("key")

    mid =
      ignore(optional_whitespace)
      |> concat(
        choice([
          string("==") |> replace(:is),
          string("!=") |> replace(:is_not),
          string("~") |> replace(:contains),
          string("!~") |> replace(:does_not_contain)
        ])
      )
      |> ignore(optional_whitespace)
      |> label("operator")

    wildcard = ascii_string([@wildcard_char], min: 1, max: 2) |> tag(:wildcard)
    word_no_space = utf8_string(@word, min: 1)

    words_with_spaces_inside =
      times(
        word_no_space
        |> concat(
          times(
            whitespace
            |> concat(word_no_space),
            min: 1
          )
        ),
        min: 1
      )

    token =
      ignore(optional_whitespace)
      |> times(choice([words_with_spaces_inside, word_no_space, wildcard]), min: 1)
      |> ignore(optional_whitespace)
      |> reduce({:mark_wildcards, []})

    alternative =
      token
      |> concat(
        times(
          concat(
            ascii_char([@alt_separator_char])
            |> ignore(),
            token
          ),
          min: 1
        )
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
      IO.inspect(args, label: :reducer)

      Enum.reduce(args, [], fn
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
      case filter(input) |> IO.inspect(label: true) do
        {:ok, [filters], "", _, _, _} ->
          {:ok, filters}

        {:ok, _, failed_to_parse, _, _, _} ->
          {:error, failed_to_parse}

        {:error, error, _, _, _, _} ->
          {:error, error}
      end
    end
  end
end
