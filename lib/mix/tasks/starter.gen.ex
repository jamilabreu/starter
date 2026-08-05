defmodule Mix.Tasks.Starter.Gen do
  @shortdoc "Generates configuration and code"

  @moduledoc """
  Runs one or more `:gen` steps by name.

  ## Usage

      mix starter.gen gitignore

  Run `mix starter.gen --list` to see every available step.
  """

  use Igniter.Mix.Task

  @impl Mix.Task
  def run(argv) do
    if "--list" in argv or "-l" in argv do
      Starter.Steps.Dispatcher.list(:gen)
    else
      super(argv)
    end
  end

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :starter,
      example: "mix starter.gen gitignore",
      positional: [{:names, optional: true}]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Starter.Steps.Dispatcher.run(igniter, :gen, igniter.args.positional[:names])
  end
end
