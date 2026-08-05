defmodule Mix.Tasks.StarterRunFixture.Workflow do
  use Starter.Workflow

  @impl Starter.Workflow
  def steps, do: []
end

defmodule StarterRunFixture.NotAWorkflow do
  def hello, do: :world
end

defmodule Mix.Tasks.Starter.RunTest do
  use ExUnit.Case, async: true

  test "find_workflow_modules keeps only workflow task modules" do
    modules = [
      Mix.Tasks.StarterRunFixture.Workflow,
      StarterRunFixture.NotAWorkflow,
      String,
      Mix.Tasks.Starter.Run
    ]

    assert Mix.Tasks.Starter.Run.find_workflow_modules(modules) ==
             [Mix.Tasks.StarterRunFixture.Workflow]
  end

  test "raises with guidance when no workflow exists" do
    assert_raise Mix.Error, ~r/mix starter\.new/, fn ->
      Mix.Tasks.Starter.Run.run([])
    end
  end
end
