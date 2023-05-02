defmodule FiltersTest do
  use ExUnit.Case
  doctest Filters

  describe "parsing literal expressions" do
    test "parses single char" do
      assert {:ok, {:literal, "f"}} ==
               parse("f", :literal_expression)
    end

    test "parses words" do
      assert {:ok, {:literal, "hello Cruel world 😅"}} ==
               parse("hello Cruel world 😅", :literal_expression)
    end

    test "strips whitespace" do
      assert {:ok, {:literal, "hello Cruel world 😅"}} ==
               parse("   hello Cruel world 😅  ", :literal_expression)
    end

    test "disregards escaped pipe" do
      assert {:ok, {:literal, "hello|world"}} ==
               parse("hello\\|world", :literal_expression)
    end

    test "disregards escaped pipe with spaces" do
      assert {:ok, {:literal, "hello  |  world"}} ==
               parse("hello  \\|  world", :literal_expression)
    end

    test "parses alternatives" do
      assert {:ok, [{:literal, "A"}, {:literal, "B"}]} ==
               parse("A|B", :literal_expression)
    end

    test "parses alternative words" do
      assert {:ok, [{:literal, "Adam"}, {:literal, "Yolanda"}]} ==
               parse("  Adam | Yolanda   ", :literal_expression)
    end

    test "parses alternative words - three" do
      assert {:ok, [{:literal, "Adam"}, {:literal, "Yolanda"}, {:literal, "Juju"}]} ==
               parse("  Adam | Yolanda | Juju  ", :literal_expression)

      assert {:ok, [{:literal, "Adam"}, {:literal, "Yolanda"}, {:literal, "Juju"}]} ==
               parse("Adam|Yolanda|Juju", :literal_expression)
    end

    test "parses alternatives and strips spaces" do
      assert {:ok, [{:literal, "A"}, {:literal, "B"}]} ==
               parse("  A|B    ", :literal_expression)
    end

    test "disregards wildcards" do
      assert {:ok, {:literal, "Hello**"}} ==
               parse("Hello**", :literal_expression)
    end
  end

  describe "parsing wildcard expressions" do
    test "parses single char into literal" do
      assert {:ok, {:literal, "f"}} ==
               parse("f", :wildcard_expression)
    end

    test "parses wildcard" do
      assert {:ok, {:wildcard, "f**"}} ==
               parse("f**", :wildcard_expression)
    end

    test "parses words wrapped with wildcards" do
      assert {:ok, {:wildcard, "**Hello World**"}} ==
               parse("**Hello World**", :wildcard_expression)
    end

    test "parses words into literal" do
      assert {:ok, {:literal, "hello Cruel world 😅"}} ==
               parse("hello Cruel world 😅", :wildcard_expression)
    end

    test "strips whitespace into literal" do
      assert {:ok, {:literal, "hello Cruel world 😅"}} ==
               parse("   hello Cruel world 😅  ", :wildcard_expression)
    end

    test "disregards escaped pipe into literal" do
      assert {:ok, {:literal, "hello|world"}} ==
               parse("hello\\|world", :wildcard_expression)
    end

    test "disregards escaped pipe with spaces into literal" do
      assert {:ok, {:literal, "hello  |  world"}} ==
               parse("hello  \\|  world", :wildcard_expression)
    end

    test "parses alternatives into literals" do
      assert {:ok, [{:literal, "A"}, {:literal, "B"}]} ==
               parse("A|B", :wildcard_expression)
    end

    test "parses alternative words into literals" do
      assert {:ok, [{:literal, "Adam"}, {:literal, "Yolanda"}]} ==
               parse("  Adam | Yolanda   ", :wildcard_expression)
    end

    test "parses alternatives and strips spaces" do
      assert {:ok, [{:literal, "A"}, {:literal, "B"}]} ==
               parse("  A|B    ", :wildcard_expression)
    end
  end

  describe "basic parsing" do
    test "parses single literal property with :is" do
      assert {:ok, [{"visit:city", :is, {:literal, "Foo Bar"}}]} ==
               parse("city==Foo Bar")
    end

    test "parses single property with :is" do
      assert {:ok, [{"visit:utm_campaign", :is, {:literal, "Foo Bar"}}]} ==
               parse("utm_campaign==Foo Bar")
    end

    test "parses single property with :is_not" do
      assert {:ok, [{"visit:utm_campaign", :is_not, {:literal, "Foo Bar  Baz"}}]} ==
               parse("utm_campaign!=Foo Bar  Baz")
    end

    test "parses single property with :contains and flips literal to a wildcard" do
      assert {:ok, [{"visit:utm_campaign", :contains, {:wildcard, "**Foo Bar**"}}]} ==
               parse("utm_campaign~Foo Bar")
    end

    test "parses single property with wildcard" do
      assert {:ok, [{"visit:utm_campaign", :is, {:wildcard, "/foo/bar/*"}}]} ==
               parse("utm_campaign==/foo/bar/*")
    end

    test "parses single property with wildcard inside" do
      assert {:ok, [{"visit:utm_campaign", :is, {:wildcard, "/foo/bar/*/baz"}}]} ==
               parse("utm_campaign==/foo/bar/*/baz")
    end

    test "parses single property with wildcard and space inside (2)" do
      assert {:ok, [{"visit:utm_campaign", :is, {:wildcard, "/foo/bar* /baz"}}]} ==
               parse("utm_campaign==/foo/bar* /baz")
    end

    test "parses single property with :does_not_contain and flips literal to a wildcard" do
      assert {:ok, [{"visit:utm_campaign", :does_not_contain, {:wildcard, "**Foo Bar**"}}]} ==
               parse("utm_campaign!~Foo Bar")
    end

    test "parses single property with :contains and normalizes the wildcard" do
      assert {:ok, [{"visit:utm_campaign", :does_not_contain, {:wildcard, "**Foo Bar**"}}]} ==
               parse("utm_campaign!~Foo Bar*")
    end

    test "parses single property with :does_not_contain and normalizes the wildcard" do
      assert {:ok, [{"visit:utm_campaign", :does_not_contain, {:wildcard, "**Foo Bar**"}}]} ==
               parse("utm_campaign!~**Foo Bar")
    end

    test "reject trailing unknown properties" do
      assert {:ok, [{"visit:utm_campaign", :is, {:literal, "foo"}}]} ==
               parse("utm_campaign==foo;unknown==hello")
    end

    test "utf-8 chars are supported" do
      assert {:ok, [{"visit:utm_campaign", :is, {:literal, "😀超"}}]} ==
               parse("utm_campaign==😀超")
    end
  end

  describe "prefixes" do
    test "goal is turned into event:goal" do
      assert {:ok, [{"event:goal", :is, {:literal, "My Goal"}}]} == parse("goal==My Goal")
    end

    test "name is turned into event:name" do
      assert {:ok, [{"event:name", :is, {:literal, "My Event"}}]} == parse("name==My Event")
    end

    test "page is turned into event:page" do
      assert {:ok, [{"event:page", :is, {:wildcard, "/blog/post/*"}}]} ==
               parse("page==/blog/post/*")
    end

    test "country is turned into visit:country" do
      assert {:ok, [{"visit:country", :is, {:literal, "EE"}}]} == parse("country==EE")
    end

    test "country must be 2 characters long" do
      assert {:ok, [{"visit:country", :is, [{:literal, "EE"}, {:literal, "XX"}]}]} ==
               parse("country==EE|XX|XYZ")
    end

    test "source is turned into visit:source" do
      assert {:ok, [{"visit:source", :is, {:literal, "foo.com"}}]} == parse("source==foo.com")
    end

    test "referrer is turned into visit:referer" do
      assert {:ok, [{"visit:referrer", :is, {:literal, "cnn.com"}}]} == parse("referrer==cnn.com")
    end

    test "utm_medium is turned into visit:utm_medium" do
      assert {:ok, [{"visit:utm_medium", :is, {:literal, "value"}}]} == parse("utm_medium==value")
    end

    test "utm_source is turned into visit:utm_source" do
      assert {:ok, [{"visit:utm_source", :is, {:literal, "value"}}]} == parse("utm_source==value")
    end

    test "utm_content is turned into visit:utm_content" do
      assert {:ok, [{"visit:utm_content", :is, {:literal, "value"}}]} ==
               parse("utm_content==value")
    end

    test "screen is turned into visit:screen" do
      assert {:ok, [{"visit:screen", :is, {:literal, "value"}}]} ==
               parse("screen==value")
    end

    test "browser is turned into visit:browser" do
      assert {:ok, [{"visit:browser", :is, {:literal, "value"}}]} ==
               parse("browser==value")
    end

    test "browser_version is turned into visit:browser_version" do
      assert {:ok, [{"visit:browser_version", :is, {:literal, "value"}}]} ==
               parse("browser_version==value")
    end

    test "os is turned into visit:os" do
      assert {:ok, [{"visit:os", :is, {:literal, "value"}}]} ==
               parse("os==value")
    end

    test "os_version is turned into visit:os_version" do
      assert {:ok, [{"visit:os_version", :is, {:literal, "value"}}]} ==
               parse("os_version==value")
    end

    test "utm_campaign is turned into visit:utm_campaign" do
      assert {:ok, [{"visit:utm_campaign", :is, {:literal, "value"}}]} ==
               parse("utm_campaign==value")
    end

    test "city is turned into visit:city" do
      assert {:ok, [{"visit:city", :is, {:literal, "value"}}]} ==
               parse("city==value")
    end

    test "region is turned into visit:region" do
      assert {:ok, [{"visit:region", :is, {:literal, "value"}}]} ==
               parse("region==value")
    end

    test "device is turned into visit:device" do
      assert {:ok, [{"visit:device", :is, {:literal, "value"}}]} ==
               parse("device==value")
    end

    test "exit_page is turned into visit:exit_page" do
      assert {:ok, [{"visit:exit_page", :is, {:literal, "value"}}]} ==
               parse("exit_page==value")
    end

    test "entry_page is turned into visit:entry_page" do
      assert {:ok, [{"visit:entry_page", :is, {:literal, "value"}}]} ==
               parse("entry_page==value")
    end
  end

  describe "quirks" do
    test "input key goal==Visit... is turned into event:page lookup with Visit removed" do
      assert {:ok, [{"event:page", :is, {:wildcard, "/blog/post/*"}}]} ==
               parse("goal==Visit /blog/post/*")
    end

    test "mixed goals" do
      assert {:ok,
              [
                {"event:page", :is, {:wildcard, "/blog/post/*"}},
                {"event:goal", :is, {:literal, "Signup"}}
              ]} ==
               parse("goal==Signup|Visit /blog/post/*")
    end

    test "custom props" do
      assert {:ok,
              [
                {"event:props:foo", :is, {:literal, "hello"}}
              ]} ==
               parse("props:foo==hello")
    end

    test "escaped pipe is treated as literal" do
      assert {:ok,
              [
                {"visit:utm_campaign", :is, {:literal, "foo|bar"}}
              ]} = parse("utm_campaign==foo\\|bar")
    end

    test "escaped pipe (with spaces) is treated as literal" do
      assert {:ok,
              [
                {"visit:utm_campaign", :is, {:literal, "foo   |   bar"}}
              ]} = parse("utm_campaign==foo   \\|   bar")
    end

    test "country validation and following filter" do
      assert {:error, "did not expect filter"} = parse("country==XXX;utm_source=foo.com")
    end
  end

  describe "muiltiple values" do
    test "parses multiple properties " do
      assert {:ok,
              [
                {"visit:utm_campaign", :is, {:literal, "Foo Bar"}},
                {"visit:utm_source", :is_not, {:literal, "Hello Cruel World"}},
                {"visit:city", :is, {:literal, "Warsaw"}}
              ]} ==
               parse("utm_campaign==Foo Bar;utm_source!=Hello Cruel World;city==Warsaw")
    end

    test "parses alternatives with :is" do
      assert {:ok,
              [
                {"visit:utm_campaign", :is,
                 [{:literal, "Foo Bar"}, {:literal, "Hello Cruel World"}]}
              ]} ==
               parse("utm_campaign==Foo Bar|Hello Cruel World")
    end

    test "parses alternatives with :is_not" do
      assert {:ok,
              [
                {"visit:utm_campaign", :is_not,
                 [{:literal, "Foo Bar"}, {:literal, "Hello Cruel World"}]}
              ]} ==
               parse("utm_campaign!=Foo Bar|Hello Cruel World")
    end

    test "parses alternatives with :contains" do
      assert {:ok,
              [
                {"visit:utm_campaign", :contains,
                 [{:wildcard, "**Foo Bar**"}, {:wildcard, "**Hello Cruel World**"}]}
              ]} ==
               parse("utm_campaign~Foo Bar|Hello Cruel World")
    end

    test "parses alternatives with :does_not_contain" do
      assert {:ok,
              [
                {"visit:utm_campaign", :does_not_contain,
                 [{:wildcard, "**Foo Bar**"}, {:wildcard, "**Hello Cruel World**"}]}
              ]} ==
               parse("utm_campaign!~Foo Bar|Hello Cruel World*")
    end

    test "parses alternatives with wildcards" do
      assert {:ok,
              [
                {"visit:utm_campaign", :is,
                 [{:wildcard, "Foo Bar**"}, {:wildcard, "Hello Cruel* World"}]}
              ]} ==
               parse("utm_campaign==Foo Bar**|Hello Cruel* World")
    end

    test "three alternatives" do
      assert {:ok,
              [
                {"visit:utm_campaign", :is, [{:literal, "A"}, {:literal, "B"}, {:literal, "Coo"}]}
              ]} ==
               parse("utm_campaign==A|B|Coo")
    end
  end

  describe "parse errors" do
    test "key missing" do
      assert {:error, "expected filter"} = parse("")
      assert {:error, "expected filter"} = parse("xx")
      assert {:error, "expected filter"} = parse(" xx")
      assert {:error, "expected filter"} = parse(" xx ")
      assert {:error, "expected filter"} = parse("xx ")
    end

    test "operator missing" do
      assert {:error, "expected filter"} = parse("country")
      assert {:error, "expected filter"} = parse("country  ")
      assert {:error, "expected filter"} = parse(" country  ")
      assert {:error, "expected filter"} = parse("    country")
      assert {:error, "expected filter"} = parse("country=")
      assert {:error, "expected filter"} = parse("country!")
    end

    test "expression missing" do
      assert {:error, "expected filter"} = parse("country==")
      assert {:error, "expected filter"} = parse(" country==")
      assert {:error, "expected filter"} = parse("country== ")
      assert {:error, "expected filter"} = parse("country == ")
      assert {:error, "expected filter"} = parse(" country == ")
    end
  end

  defp parse(input, parse_with \\ :filters) do
    {time, result} = :timer.tc(fn -> Filters.Parser.parse(input, parse_with) end)

    if Filters.Parser.debug?() do
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
