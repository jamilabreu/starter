defmodule Mix.Tasks.StarterRunFixture.Starter do
  use Starter

  @impl Starter
  def steps, do: []
end

defmodule StarterRunFixture.NotAStarter do
  def hello, do: :world
end

defmodule Mix.Tasks.Starter.RunTest do
  use ExUnit.Case, async: true

  test "find_starter_modules keeps only starter task modules" do
    modules = [
      Mix.Tasks.StarterRunFixture.Starter,
      StarterRunFixture.NotAStarter,
      String,
      Mix.Tasks.Starter.Run
    ]

    assert Mix.Tasks.Starter.Run.find_starter_modules(modules) ==
             [Mix.Tasks.StarterRunFixture.Starter]
  end

  test "raises with guidance when no starter exists" do
    assert_raise Mix.Error, ~r/mix starter\.new/, fn ->
      Mix.Tasks.Starter.Run.run([])
    end
  end
end
