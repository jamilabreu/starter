defmodule Mix.Tasks.Starter.Add.Bun do
  @shortdoc "Replaces esbuild and tailwind with Bun"
  @moduledoc "Replaces the `esbuild` and `tailwind` asset pipeline with `bun`."
  use Igniter.Mix.Task

  alias Starter.Helpers
  alias Starter.Versions

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> remove_esbuild()
    |> remove_tailwind()
    |> add_dep()
    |> add_package_json()
    |> clean_deploy_script()
    |> update_tsconfig()
    |> edit_config()
    |> edit_config_dev()
    |> edit_mix_aliases()
    |> Igniter.add_task("assets.setup")
  end

  defp add_dep(igniter) do
    if Igniter.Project.Deps.has_dep?(igniter, :bun) do
      igniter
    else
      {package, version} = Versions.latest_hex_dep(:bun)
      runtime = Sourceror.parse_string!("Mix.env() == :dev")

      igniter
      |> Igniter.Project.Deps.add_dep({package, version})
      |> Igniter.Project.Deps.set_dep_option(:bun, :runtime, runtime)
    end
  end

  defp add_package_json(igniter) do
    has_topbar? = Igniter.exists?(igniter, "assets/vendor/topbar.js")

    packages =
      if has_topbar?,
        do: ["tailwindcss", "@tailwindcss/cli", "topbar", "bun"],
        else: ["tailwindcss", "@tailwindcss/cli", "bun"]

    versions = Versions.fetch_npm_versions(packages)

    dependencies = %{
      "phoenix" => "workspace:*",
      "phoenix_html" => "workspace:*",
      "phoenix_live_view" => "workspace:*",
      "tailwindcss" => "^#{versions["tailwindcss"] || "4.1.18"}",
      "@tailwindcss/cli" => "^#{versions["@tailwindcss/cli"] || "4.1.18"}"
    }

    dependencies =
      if has_topbar? do
        Map.put(dependencies, "topbar", "^#{versions["topbar"] || "3.0.0"}")
      else
        dependencies
      end

    new_data = %{"workspaces" => ["../deps/*"], "dependencies" => dependencies}

    if Igniter.exists?(igniter, "assets/package.json") do
      Helpers.update_file_content(igniter, "assets/package.json", fn content ->
        content
        |> Jason.decode!()
        |> Map.update("workspaces", ["../deps/*"], &Enum.uniq(&1 ++ ["../deps/*"]))
        |> Map.update("dependencies", dependencies, &Map.merge(&1, dependencies))
        |> Jason.encode!(pretty: true)
        |> Kernel.<>("\n")
      end)
    else
      contents = Jason.encode!(new_data, pretty: true)
      Igniter.create_new_file(igniter, "assets/package.json", contents <> "\n")
    end
  end

  defp clean_deploy_script(igniter) do
    if Igniter.exists?(igniter, "assets/package.json") do
      Igniter.update_file(igniter, "assets/package.json", fn source ->
        content = Rewrite.Source.get(source, :content)
        json = Jason.decode!(content)

        case get_in(json, ["scripts", "deploy"]) do
          nil ->
            source

          deploy_script ->
            cleaned = String.replace(deploy_script, ~r/ && rm -f _build\/esbuild\*?/, "")
            updated = put_in(json, ["scripts", "deploy"], cleaned)
            Rewrite.Source.update(source, :content, Jason.encode!(updated, pretty: true) <> "\n")
        end
      end)
    else
      igniter
    end
  end

  # phx.new's assets/tsconfig.json aliases "*" to ../deps for editor support and
  # documents that the alias should be dropped once a package.json manages the
  # phoenix packages — which add_package_json/1 now does.
  defp update_tsconfig(igniter) do
    path = "assets/tsconfig.json"

    if Igniter.exists?(igniter, path) do
      Helpers.update_file_content(igniter, path, fn content ->
        content
        |> String.replace(~r/\s*"baseUrl": "[^"]*",/, "")
        |> String.replace(~r/\s*"paths": \{[^}]*\},?/, "")
      end)
    else
      igniter
    end
  end

  defp remove_esbuild(igniter) do
    igniter
    |> Igniter.Project.Config.remove_application_configuration("config.exs", :esbuild)
    |> Igniter.Project.Deps.remove_dep(:esbuild)
  end

  defp remove_tailwind(igniter) do
    igniter
    |> Igniter.Project.Config.remove_application_configuration("config.exs", :tailwind)
    |> Igniter.Project.Deps.remove_dep(:tailwind)
  end

  # Re-merging the ~w() sigil config into a file that already contains it
  # crashes rewrite's formatter, so config edits are skip-on-rerun.
  defp edit_config(igniter) do
    if file_contains?(igniter, "config/config.exs", "config :bun") do
      igniter
    else
      do_edit_config(igniter)
    end
  end

  defp do_edit_config(igniter) do
    version = Versions.fetch_npm_version("bun") || "1.3.5"

    igniter
    |> Igniter.Project.Config.configure("config.exs", :bun, [:version], version)
    |> Igniter.Project.Config.configure(
      "config.exs",
      :bun,
      [:assets],
      {:code, quote(do: [args: [], cd: Path.expand("../assets", __DIR__)])}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :bun,
      [:css],
      {:code,
       quote(
         do: [
           args:
             ~w(run tailwindcss --input=css/app.css --output=../priv/static/assets/css/app.css),
           cd: Path.expand("../assets", __DIR__)
         ]
       )}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :bun,
      [:js],
      {:code,
       quote(
         do: [
           args:
             ~w(build js/app.js --outdir=../priv/static/assets/js --external /fonts/* --external /images/*),
           cd: Path.expand("../assets", __DIR__)
         ]
       )}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :phoenix_live_view,
      [:colocated_assets],
      {:code,
       quote(
         do: [
           target_directory: Path.expand("../assets/node_modules/phoenix-colocated", __DIR__)
         ]
       )}
    )
  end

  defp edit_config_dev(igniter) do
    if file_contains?(igniter, "config/dev.exs", "bun_css:") do
      igniter
    else
      app_name = Igniter.Project.Application.app_name(igniter)
      endpoint = Module.concat([Helpers.app_web_module(igniter), "Endpoint"])

      Igniter.Project.Config.configure(
        igniter,
        "dev.exs",
        app_name,
        [endpoint, :watchers],
        bun_css: {Bun, :install_and_run, [:css, ~w(--watch)]},
        bun_js: {Bun, :install_and_run, [:js, ~w(--sourcemap=inline --watch)]}
      )
    end
  end

  defp file_contains?(igniter, path, text) do
    if Igniter.exists?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)

      igniter.rewrite
      |> Rewrite.source!(path)
      |> Rewrite.Source.get(:content)
      |> String.contains?(text)
    else
      false
    end
  end

  defp edit_mix_aliases(igniter) do
    igniter
    |> Igniter.Project.TaskAliases.modify_existing_alias("assets.setup", fn zipper ->
      {:ok, Sourceror.Zipper.replace(zipper, ["bun.install --if-missing", "bun assets install"])}
    end)
    |> Igniter.Project.TaskAliases.modify_existing_alias("assets.build", fn zipper ->
      {:ok, Sourceror.Zipper.replace(zipper, ["bun css", "bun js"])}
    end)
    |> Igniter.Project.TaskAliases.modify_existing_alias("assets.deploy", fn zipper ->
      {:ok,
       Sourceror.Zipper.replace(zipper, ["bun css --minify", "bun js --minify", "phx.digest"])}
    end)
  end
end
