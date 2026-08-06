defmodule Mix.Tasks.Starter.Add do
  @shortdoc "Adds and configures packages"

  @moduledoc """
  Runs one or more `:add` steps by name.

  ## Usage

      mix starter.add credo
      mix starter.add credo,quokka

  Run `mix starter.add --list` to see every available step.

  This task runs Starter's built-in steps only. For a package that ships its
  own Igniter installer (`oban`, `ash`, …), use `mix igniter.install` — or
  `{:add, :name}` in a starter, which resolves either way.
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
      example: "mix starter.add credo",
      positional: [{:names, optional: true}]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Starter.Steps.Dispatcher.run(igniter, :add, igniter.args.positional[:names])
  end
end
