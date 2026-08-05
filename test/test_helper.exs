# Keep tests offline: dependency versions fall back to permissive ranges.
Application.put_env(:starter, :fetch_versions, false)

ExUnit.start()
