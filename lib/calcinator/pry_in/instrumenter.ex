if Code.ensure_loaded?(PryIn) do
  # Based on https://github.com/pryin-io/pryin/blob/9fec04d61a7b8d4ff337653294f13c4e345c7029/lib/pryin/instrumenter.ex
  defmodule Calcinator.PryIn.Instrumenter do
    @moduledoc """
    Collects metrics about

    * `Calcinator.can/3`

    Activate via:

    ```elixir
    config :calcinator,
           instrumenters: [Calcinator.PryIn.Instrumenter]
    ```

    """

    import PryIn.{InteractionHelper, TimeHelper}

    alias PryIn.InteractionStore

    # Functions

    ## Calcinator.Instrumenter event callbacks

    @doc """
    Collects metrics about `Calcinator.can/3` calls.

    Metrics are only collected inside of tracked interactions
    """

    def calcinator_can(:start, %{file: file, function: function, line: line, module: module}, runtime_metadata) do
      metadata = Map.merge(runtime_metadata, %{file: file, function: function, line: line, module: module})

      if InteractionStore.has_pid?(self()) do
        now = utc_unix_datetime()
        offset = now - InteractionStore.get_field(self(), :start_time)
        Map.put(metadata, :offset, offset)
      else
        metadata
      end
    end

    def calcinator_can(
          :stop,
          time_diff,
          %{
            action: action,
            calcinator: %{
              authorization_module: authorization_module,
              subject: subject
            },
            file: file,
            function: function,
            line: line,
            module: module,
            target: target
          }
        ) do
      if InteractionStore.has_pid?(self()) do
        target_prefix = "calcinator/can/actions/#{action}/targets/#{target_name(target)}"
        InteractionStore.put_context(self(), "#{target_prefix}/subject", subject_name(subject))
        InteractionStore.put_context(self(), "#{target_prefix}/authorization_module", module_name(authorization_module))

        data = [
          duration: System.convert_time_unit(time_diff, :native, :microseconds),
          file: file,
          function: function,
          key: "calcinator_can_#{action}",
          line: line,
          module: module_name(module),
          pid: inspect(self())
        ]
        InteractionStore.add_custom_metric(self(), data)
      end
    end

    def calcinator_can(:stop, _time_diff, _), do: :ok

    ## Private Functions

    defp subject_name(nil), do: "nil"
    defp subject_name(%subject_module{}), do: "%#{module_name(subject_module)}{}"

    defp target_name(nil), do: "nil"
    defp target_name(target) when is_atom(target), do: module_name(target)
    defp target_name(%target_module{data: data}) when target_module == Ecto.Changeset do
      "%#{module_name(target_module)}{data: #{target_name(data)}}"
    end
    defp target_name(%target_module{}), do: "%#{target_name(target_module)}{}"
    defp target_name(association_ascent) when is_list(association_ascent) do
      "[#{Enum.map_join(association_ascent, ", ", &target_name/1)}]"
    end
  end
end
