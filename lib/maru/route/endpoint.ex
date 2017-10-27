alias Maru.Route

defmodule Route.Endpoint do
  defstruct func_id:    nil,
            block:      nil,
            has_params: true

  defmacro __using__(_) do
    quote do
      Module.register_attribute __MODULE__, :endpoints, accumulate: true
    end
  end

  def before_method(%{module: module}) do
    route = Module.get_attribute(module, :route)
    endpoint =
      Module.get_attribute(module, :method_context)
      |> Map.take([:block, :func_id])
      |> Map.put(:has_params, [] != route.parameters)
    Module.put_attribute(module, :endpoints, struct(Route.Endpoint, endpoint))
  end

  def before_compile_router(%Macro.Env{module: module}=env) do
    quoted =
      Module.get_attribute(module, :endpoints)
      |> Enum.reverse
      |> Enum.map(&Route.Endpoint.Helper.dispatch/1)

    Module.eval_quoted(env, quoted)
  end

end

defmodule Route.Endpoint.Helper do
  @doc """
  Generate endpoint called within route block.
  """
  def dispatch(ep) do
    conn =
      if ep.has_params do
        quote do
          %Plug.Conn{
            private: %{
              maru_params: var!(params)
            }
          } = var!(conn)
        end
      else
        quote do: var!(conn)
      end
    quote do
      def endpoint(unquote(conn), unquote(ep.func_id)) do
        unquote(ep.block)
      end
    end
  end
end
R