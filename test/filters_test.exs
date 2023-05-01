defmodule FiltersTest do
  use ExUnit.Case
  doctest Filters

  @debug false

  describe "simple cases" do
    test "parses single property with :is" do
      assert {:ok, [{"utm_campaign", :is, {:literal, "Foo Bar"}}]} ==
               parse("utm_campaign==Foo Bar")
    end

    test "parses single property with :is_not" do
      assert {:ok, [{"utm_campaign", :is_not, {:literal, "Foo Bar"}}]} ==
               parse("utm_campaign!=Foo Bar")
    end

    test "parses single property with :contains and flips literal to a wildcard" do
      assert {:ok, [{"utm_campaign", :contains, {:wildcard, "**Foo Bar**"}}]} ==
               parse("utm_campaign~Foo Bar")
    end

    test "parses single property with wildcard inside" do
      assert {:ok, [{"utm_campaign", :is, {:wildcard, "/foo/bar/*/baz"}}]} ==
               parse("utm_campaign==/foo/bar/*/baz")
    end

    test "parses single property with wildcard and space inside (2)" do
      assert {:ok, [{"utm_campaign", :is, {:wildcard, "/foo/bar*/baz"}}]} ==
               parse("utm_campaign==/foo/bar* /baz")
    end

    test "parses single property with :does_not_contain and flips literal to a wildcard" do
      assert {:ok, [{"utm_campaign", :does_not_contain, {:wildcard, "**Foo Bar**"}}]} ==
               parse("utm_campaign!~Foo Bar")
    end

    test "parses single property with :contains and normalizes the wildcard" do
      assert {:ok, [{"utm_campaign", :does_not_contain, {:wildcard, "**Foo Bar**"}}]} ==
               parse("utm_campaign!~Foo Bar*")
    end

    test "parses single property with :does_not_contain and normalizes the wildcard" do
      assert {:ok, [{"utm_campaign", :does_not_contain, {:wildcard, "**Foo Bar**"}}]} ==
               parse("utm_campaign!~**Foo Bar")
    end

    test "reject unknown properties" do
      :ok
    end
  end

  describe "muiltiple values" do
    test "parses multiple properties " do
      assert {:ok,
              [
                {"utm_campaign", :is, {:literal, "Foo Bar"}},
                {"utm_source", :is_not, {:literal, "Hello Cruel World"}}
              ]} ==
               parse("utm_campaign==Foo Bar;utm_source!=Hello Cruel World")
    end

    test "parses alternatives with :is" do
      assert {:ok,
              [
                {"utm_campaign", :is, [{:literal, "Foo Bar"}, {:literal, "Hello Cruel World"}]}
              ]} ==
               parse("utm_campaign==Foo Bar|Hello Cruel World")
    end

    test "parses alternatives with :is_not" do
      assert {:ok,
              [
                {"utm_campaign", :is_not,
                 [{:literal, "Foo Bar"}, {:literal, "Hello Cruel World"}]}
              ]} ==
               parse("utm_campaign!=Foo Bar|Hello Cruel World")
    end

    test "parses alternatives with :contains" do
      assert {:ok,
              [
                {"utm_campaign", :contains,
                 [{:wildcard, "**Foo Bar**"}, {:wildcard, "**Hello Cruel World**"}]}
              ]} ==
               parse("utm_campaign~Foo Bar|Hello Cruel World")
    end

    test "parses alternatives with :does_not_contain" do
      assert {:ok,
              [
                {"utm_campaign", :does_not_contain,
                 [{:wildcard, "**Foo Bar**"}, {:wildcard, "**Hello Cruel World**"}]}
              ]} ==
               parse("utm_campaign!~Foo Bar|Hello Cruel World*")
    end

    test "parses alternatives with wildcards" do
      assert {:ok,
              [
                {"utm_campaign", :does_not_contain,
                 [{:wildcard, "**Foo Bar**"}, {:wildcard, "**Hello Cruel World**"}]}
              ]} ==
               parse("utm_campaign==Foo Bar**|Hello Cruel* World")
    end
  end

  describe "parse errors" do
    test "key missing" do
      assert {:error, "expected key name while processing key"} = parse("")
      assert {:error, "expected key name while processing key"} = parse("xx")
      assert {:error, "expected key name while processing key"} = parse(" xx")
      assert {:error, "expected key name while processing key"} = parse(" xx ")
      assert {:error, "expected key name while processing key"} = parse("xx ")
    end

    test "operator missing" do
      assert {:error, "expected operator"} = parse("country")
      assert {:error, "expected operator"} = parse("country  ")
      assert {:error, "expected operator"} = parse(" country  ")
      assert {:error, "expected operator"} = parse("    country")
      assert {:error, "expected operator"} = parse("country=")
      assert {:error, "expected operator"} = parse("country!")
    end

    test "expression missing" do
      assert {:error, "expected expression"} = parse("country==")
      assert {:error, "expected expression"} = parse(" country==")
      assert {:error, "expected expression"} = parse("country== ")
      assert {:error, "expected expression"} = parse("country == ")
      assert {:error, "expected expression"} = parse(" country == ")
    end
  end

  test "greets the world" do
    # parse("foo==bar")
    # parse("foo!=bar")
    # parse("foo!~=bar")
    # parse("foo~bar")
    # parse("foo==bar**")
    # parse("foo==*bar*")
    # parse("foo==bar;baz==bam")
    # parse("   foobar  ==      baz bam baz   ")
    # parse("foo==bar|bam beng foo  |bang mooo   ")
    # parse("foo==bar|bam beng foo  |bang mooo** ;xxxx==yyyy  ")
    # parse("xxxx")
  end

  defp parse(input) do
    {time, result} = :timer.tc(fn -> Filters.Parser.parse_filters(input) end)

    if @debug do
      IO.puts(inspect(time / 1_000) <> "ms \t" <> IO.ANSI.bright() <> input <> "\t")

      case result do
        {:ok, _result} ->
          IO.ANSI.blue() |> IO.puts()

        _ ->
          IO.ANSI.red() |> IO.puts()
      end

      IO.puts(inspect(result))

      IO.ANSI.reset()
      |> IO.puts()
    end

    result
  end
end
