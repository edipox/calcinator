if Code.ensure_loaded?(PryIn) do
  # Based on https://github.com/pryin-io/pryin/blob/9fec04d61a7b8d4ff337653294f13c4e345c7029/lib/pryin/instrumenter.ex
  defmodule Calcinator.PryIn.Instrumenter do
    @moduledoc """
    Collects metrics about

    * `:calcinator_authorization`
      * `Calcinator.authorized/2`
      * `Calcinator.can/3`
    * `:calcinator_view`
      * `view_module` calls

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
    Collects metrics about `Calcinator.Authorization` behaviour calls from `Calcinator`.

    Metrics are only collected inside of tracked interactions
    """

    def calcinator_authorization(:start, compile_metadata, runtime_metadata) do
      start(compile_metadata, runtime_metadata)
    end

    def calcinator_authorization(
          :stop,
          time_diff,
          metadata = %{
            action: action,
            calcinator: %{
              authorization_module: authorization_module,
              subject: subject
            },
            target: target
          }
        ) do
      if InteractionStore.has_pid?(self()) do
        event = "calcinator_authorization"
        prefix = unique_prefix(event)
        InteractionStore.put_context(self(), "#{prefix}/authorization_module", module_name(authorization_module))
        InteractionStore.put_context(self(), "#{prefix}/subject", subject_name(subject))
        InteractionStore.put_context(self(), "#{prefix}/action", to_string(action))
        InteractionStore.put_context(self(), "#{prefix}/target", target_name(target))

        metadata
        |> Map.merge(%{key: event, time_diff: time_diff})
        |> add_custom_metric()
      end
    end

    def calcinator_authorization(:stop, _time_diff, _), do: :ok

    def calcinator_view(:start, compile_metadata, runtime_metadata), do: start(compile_metadata, runtime_metadata)

    def calcinator_view(
          :stop,
          time_diff,
          metadata = %{
            args: args,
            calcinator: %{
              view_module: view_module
            },
            callback: callback
          }
        ) do
      if InteractionStore.has_pid?(self()) do
        put_calcinator_view_context(%{args: args, callback: callback, view_module: view_module})

        metadata
        |> Map.merge(%{key: "calcinator_view", time_diff: time_diff})
        |> add_custom_metric()
      end
    end

    #def calcinator_view(:stop, _time_diff, metadata), do: (IO.inspect(metadata); :ok)

    ## Private Functions

    defp add_custom_metric(
           metadata = %{file: file, function: function, key: key, line: line, module: module, time_diff: time_diff}
         ) do
      data = [
        duration: System.convert_time_unit(time_diff, :native, :microseconds),
        file: file,
        function: function,
        key: key,
        line: line,
        module: module_name(module),
        pid: inspect(self())
      ]

      full_data = case Map.fetch(metadata, :offset) do
        {:ok, offset} -> Keyword.put(data, :offset, offset)
        :error -> data
      end

      InteractionStore.add_custom_metric(self(), full_data)
    end

    defp put_calcinator_view_context(
           %{
             args: [
               related_resource,
               %{
                 related: %{resource: related_resource},
                 source: %{association: source_association, resource: source_resource},
                 subject: subject
               }
             ],
             callback: callback,
             prefix: prefix,
             view_module: view_module
           }
         ) when callback in ~w(get_related_resource show_relationship)a do
      put_calcinator_view_context(%{callback: callback, prefix: prefix, subject: subject, view_module: view_module})
      InteractionStore.put_context(self(), "#{prefix}/source_resource", target_name(source_resource))
      InteractionStore.put_context(self(), "#{prefix}/source_association", target_name(source_association))
      InteractionStore.put_context(self(), "#{prefix}/related_resource", target_name(related_resource))
    end

    defp put_calcinator_view_context(
           %{
             args: [resources, %{subject: subject}],
             callback: callback = :index,
             prefix: prefix,
             view_module: view_module
           }
         ) do
      put_calcinator_view_context(%{callback: callback, prefix: prefix, subject: subject, view_module: view_module})
      InteractionStore.put_context(self(), "#{prefix}/resources", target_name(resources))
    end

    defp put_calcinator_view_context(
           %{
             args: [resource, %{subject: subject}],
             callback: callback = :show,
             prefix: prefix,
             view_module: view_module
           }
         ) do
      put_calcinator_view_context(%{callback: callback, prefix: prefix, subject: subject, view_module: view_module})
      InteractionStore.put_context(self(), "#{prefix}/resource", target_name(resource))
    end

    defp put_calcinator_view_context(
           %{callback: callback, prefix: prefix, subject: subject, view_module: view_module}
         ) do
      InteractionStore.put_context(self(), "#{prefix}/view_module", module_name(view_module))
      InteractionStore.put_context(self(), "#{prefix}/callback", to_string(callback))
      InteractionStore.put_context(self(), "#{prefix}/subject", subject_name(subject))
    end

    defp put_calcinator_view_context(options) when is_map(options) do
      options
      |> Map.put(:prefix, unique_prefix("calcinator_view"))
      |> put_calcinator_view_context()
    end

    defp start(%{file: file, function: function, line: line, module: module}, runtime_metadata) do
      metadata = Map.merge(runtime_metadata, %{file: file, function: function, line: line, module: module})

      if InteractionStore.has_pid?(self()) do
        now = utc_unix_datetime()
        offset = now - InteractionStore.get_field(self(), :start_time)
        Map.put(metadata, :offset, offset)
      else
        metadata
      end
    end

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

    defp unique_prefix(prefix) do
      "#{prefix}/#{:erlang.unique_integer([:positive])}"
    end
  end
end
