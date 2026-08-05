defmodule Mix.Tasks.Starter.Gen.Gigalixir do
  @shortdoc "Generates Gigalixir deployment configuration"
  @moduledoc """
  Generates Gigalixir deployment configuration: buildpacks, Procfile,
  release scripts, and production SSL/endpoint config.

  Includes an Oban Pro repo hook in the buildpack config only when the
  project depends on `oban_pro`.
  """
  use Igniter.Mix.Task

  alias Starter.Helpers
  alias Starter.Versions

  @erlang_default "28.3"
  @elixir_default "1.19.4"

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_elixir_buildpack()
    |> add_buildpacks_file()
    |> add_build_assets_script()
    |> add_procfile()
    |> add_scripts_module()
    |> configure_repo_ssl()
    |> configure_endpoint_server()
    |> edit_package_json()
    |> remove_colocated_hooks()
    |> add_notices()
  end

  defp add_elixir_buildpack(igniter) do
    erlang = fetch_latest_erlang() || @erlang_default
    elixir = fetch_latest_elixir() || @elixir_default

    oban_pro_hook =
      if Igniter.Project.Deps.has_dep?(igniter, :oban_pro) do
        """

        # Fetch Oban Pro
        hook_pre_fetch_dependencies="mix hex.repo add oban https://repo.oban.pro --fetch-public-key SHA256:4/OSKi0NRF91QVVXlGAhb/BIMLnK8NHcx/EWs+aIWPc --auth-key ${OBAN_PRO_AUTH_KEY}"
        """
      else
        ""
      end

    content = """
    erlang_version=#{erlang}
    elixir_version=#{elixir}
    #{oban_pro_hook}
    # Run custom asset build after compilation
    hook_post_compile="./build_assets"
    """

    create_or_replace(igniter, "elixir_buildpack.config", content)
  end

  defp add_buildpacks_file(igniter) do
    content = """
    https://github.com/gigalixir/gigalixir-buildpack-elixir
    https://github.com/gigalixir/gigalixir-buildpack-releases.git
    """

    create_or_replace(igniter, ".buildpacks", content)
  end

  defp create_or_replace(igniter, path, content) do
    if Igniter.exists?(igniter, path) do
      Igniter.update_file(igniter, path, fn source ->
        Rewrite.Source.update(source, :content, content)
      end)
    else
      Igniter.create_new_file(igniter, path, content)
    end
  end

  defp add_build_assets_script(igniter) do
    content = """
    #!/usr/bin/env bash

    set -e

    echo "-----> Setting up assets..."
    mix assets.setup

    echo "-----> Deploying assets..."
    mix assets.deploy

    echo "-----> Assets built successfully!"
    """

    Igniter.create_new_file(igniter, "build_assets", content)
  end

  defp add_procfile(igniter) do
    scripts_module = Igniter.Project.Module.module_name(igniter, "Scripts")

    content = """
    web: /app/bin/$GIGALIXIR_APP_NAME eval '#{scripts_module}.migrate' && /app/bin/$GIGALIXIR_APP_NAME $GIGALIXIR_COMMAND
    """

    Igniter.create_new_file(igniter, "rel/overlays/Procfile", content)
  end

  defp add_scripts_module(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    scripts_module = Igniter.Project.Module.module_name(igniter, "Scripts")

    content = """
    defmodule #{inspect(scripts_module)} do
      def migrate do
        load_app()

        for repo <- repos() do
          {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
        end
      end

      def rollback(repo, version) do
        load_app()
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
      end

      defp repos do
        Application.fetch_env!(:#{app_name}, :ecto_repos)
      end

      defp load_app do
        # Many platforms require SSL when connecting to the database
        Application.ensure_all_started(:ssl)
        Application.ensure_loaded(:#{app_name})
      end
    end
    """

    Igniter.create_new_file(igniter, "lib/#{app_name}/scripts.ex", content)
  end

  defp configure_repo_ssl(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)

    ssl_opts =
      {:code,
       Sourceror.parse_string!("[verify: :verify_none, cacerts: :public_key.cacerts_get()]")}

    Igniter.Project.Config.configure_runtime_env(igniter, :prod, app_name, [repo, :ssl], ssl_opts)
  end

  defp configure_endpoint_server(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    endpoint = Module.concat([Helpers.app_web_module(igniter), "Endpoint"])

    Igniter.Project.Config.configure_runtime_env(
      igniter,
      :prod,
      app_name,
      [endpoint, :server],
      true
    )
  end

  defp edit_package_json(igniter) do
    has_esbuild? = Igniter.Project.Deps.has_dep?(igniter, :esbuild)

    deploy_script =
      if has_esbuild?,
        do: "cd .. && mix assets.deploy && rm -f _build/esbuild*",
        else: "cd .. && mix assets.deploy"

    if Igniter.exists?(igniter, "assets/package.json") do
      Igniter.update_file(igniter, "assets/package.json", fn source ->
        content = Rewrite.Source.get(source, :content)

        updated =
          content
          |> Jason.decode!()
          |> put_in([Access.key("scripts", %{}), "deploy"], deploy_script)
          |> Jason.encode!(pretty: true)

        Rewrite.Source.update(source, :content, updated <> "\n")
      end)
    else
      content =
        %{"scripts" => %{"deploy" => deploy_script}}
        |> Jason.encode!(pretty: true)

      Igniter.create_new_file(igniter, "assets/package.json", content <> "\n")
    end
  end

  # Colocated hooks are written under _build at compile time, which Gigalixir's
  # asset build cannot see — drop the import so production builds succeed.
  # Skipped when the bun step is present (it retargets colocated output into
  # assets/node_modules, which the buildpack can see).
  defp remove_colocated_hooks(igniter) do
    app_js_path = "assets/js/app.js"
    app_name = Igniter.Project.Application.app_name(igniter)
    import_regex = ~r/import \{hooks as colocatedHooks\} from "phoenix-colocated\/#{app_name}"\n/

    cond do
      not Igniter.exists?(igniter, app_js_path) ->
        igniter

      Igniter.Project.Deps.has_dep?(igniter, :bun) ->
        igniter

      true ->
        igniter = Igniter.include_existing_file(igniter, app_js_path)
        content = Rewrite.source!(igniter.rewrite, app_js_path) |> Rewrite.Source.get(:content)

        cond do
          not Regex.match?(import_regex, content) ->
            igniter

          # The hooks option was merged with other hooks — removing only the
          # import would leave a dangling colocatedHooks reference.
          String.contains?(content, "...colocatedHooks,") ->
            Igniter.add_warning(igniter, """
            assets/js/app.js merges colocatedHooks with other hooks, so it was \
            left untouched. Gigalixir's asset build cannot see colocated hooks \
            (they live in _build) — remove the phoenix-colocated import and the \
            colocatedHooks entry manually, or move your hooks out of colocated \
            components.
            """)

          true ->
            igniter
            |> Helpers.update_file_content(app_js_path, fn content ->
              content
              |> String.replace(import_regex, "")
              |> String.replace(~r/\s*hooks: \{\.\.\.colocatedHooks\},?\n/, "")
            end)
            |> Igniter.add_notice("""
            Removed the colocated JS hooks import from assets/js/app.js: \
            Gigalixir's asset build cannot see colocated hooks (they live in \
            _build). If you use colocated hooks, consider the bun step, which \
            retargets them into assets/node_modules.
            """)
        end
    end
  end

  defp add_notices(igniter) do
    igniter
    |> Igniter.add_notice("Run: chmod +x ./build_assets")
    |> then(fn ig ->
      if Igniter.Project.Deps.has_dep?(ig, :oban_pro) do
        Igniter.add_notice(ig, "Run: gigalixir config:set OBAN_PRO_AUTH_KEY=<your-key>")
      else
        ig
      end
    end)
    |> Igniter.add_notice(
      "Run: gigalixir create -n \"your-app-name\" && gigalixir pg:create --free && git push gigalixir"
    )
  end

  defp fetch_latest_erlang do
    case Versions.fetch_github_tag("erlang", "otp") do
      "OTP-" <> version -> version
      _ -> nil
    end
  end

  defp fetch_latest_elixir do
    case Versions.fetch_github_tag("elixir-lang", "elixir") do
      "v" <> version -> version
      _ -> nil
    end
  end
end
