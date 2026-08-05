defmodule Mix.Tasks.Starter.Add do
  @shortdoc "Adds and configures packages"

  @moduledoc """
  Runs one or more `:add` steps by name.

  ## Usage

      mix starter.add oban
      mix starter.add oban,credo

  Run `mix starter.add --list` to see every available step.
  """

  use Igniter.Mix.Task

  @impl Mix.Task
  def run(argv) do
    if "--list" in argv or "-l" in argv do
      Starter.Steps.Dispatcher.list(:add)
    else
      super(argv)
    end
  end

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :starter,
      example: "mix starter.add oban",
      positional: [{:names, optional: true}]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Starter.Steps.Dispatcher.run(igniter, :add, igniter.args.positional[:names])
  end
end
