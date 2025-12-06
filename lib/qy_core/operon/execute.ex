defmodule QyCore.Operon.Execute do
  @behaviour QyCore.Operon

  alias QyCore.Operon.{Request, Responce}

  @impl true
  def call(%Request{} = req, _) do
    {executor, executor_opts} = req.executor_and_opts

    %Responce{
      payload: executor.execute(req.recipe, req.inital_param, executor_opts),
      assigns: req.assigns
    }
  end
end
