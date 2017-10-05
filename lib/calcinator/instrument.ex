# Based on https://raw.githubusercontent.com/phoenixframework/phoenix/d6106c692311a2dfbba95243af144481124aad46/lib/
#   phoenix/endpoint/instrument.ex
# Switch to the generic Application Performance Monitor library once Chris McCord releases it.
defmodule Calcinator.Instrument do
  @moduledoc """
  Similar to Phoenix, Calcinator supports instrumenters that can receive events from `Calcinator`.

  The `instrument/3` macro is responsible for measuring the time it takes for the event to be processed and for
  notifying a list of interested instrumenter modules of this measurement.

  You can configure this list of instrumenter modules in the compile-time
  configuration for Calcinator.

      config :calcinator,
             instrumenters: [MyApp.Instrumenter]

  The way these modules express their interest in events is by exporting public functions where the name of each
  function is the name of an event.  The list of defined events is in "Events" section below.

  ### Callbacks cycle

  The event callback sequence is:

    1. The event callback is called *before* the event happens with the atom `:start` as the first argument; see the
       "`:start` clause" section below.
    2. The event occurs
    3. The same event callback is called again, this time with the atom `:stop` as the first argument; see the
       "`:stop` clause" section below.

  The second and third argument that each event callback takes depends on the value of the first argument, `:start` or
  `:stop`. For this reason, most of the time you will want to define (at least) two separate clauses for each event
  callback, one for the `:start` and one for the `:stop` callbacks.

  All event callbacks are run in the same process that calls the `instrument/3` macro; hence, instrumenters should be
  careful to avoid performing blocking actions. If an event callback fails in any way (exits, throws, or raises), it
  won't affect anything as the error is caught, but the failure will be logged. Note that `:stop` callbacks are not
  guaranteed to be called as, for example, a link may break before they've been called.

  #### `:start` clause

  When the first argument to an event callback is `:start`, the signature of that callback is:

      event_callback(:start,
                     compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                     runtime_metadata :: map) :: any

  where:

    * `compile_metadata` is a map of compile-time metadata about the environment
      where `instrument/3` has been called.
      * `:function` - "\#{name}/\#{arity}" of function where `instrument/3` has been called.
    * `runtime_metadata` is a map of runtime data that the instrumentation passes to the callbacks. It varies per call.
      See "Events" below for a list of defined events.

  #### `:stop` clause

  When the first argument to an event callback is `:stop`, the signature of that callback is:

      event_callback(:stop, time_diff :: non_neg_integer, result_of_start_callback :: any)

  where:

    * `time_diff` is an integer representing the time it took to execute the instrumented function **in native units**.
    * `result_of_start_callback` is the return value of the `:start` clause of the same `event_callback`. This is a
       means of passing data from the `:start` clause to the `:stop` clause when instrumenting.

  The return value of each `:start` event callback will be stored and passed to the corresponding `:stop` callback.

  ### Events

  ### `:calcinator_can`

  `:calcinator_can` occurs around calls to the `authorization_module.can?/3` in `Calcinator.can?/3` to measure how long
  it takes to authorize actions on the primary target.

  #### `:create`

  There are two calls to authorize `:create`.

  The first call will use the `ecto_schema_module` as the `target` to check if `ecto_schema_module` structs can be
  created in general by the `subject`.

      calcinator_can(:start,
                     compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                     runtime_metdata :: %{action: :create
                                          calcinator: %Calcinator{
                                            authorizaton_module: module
                                            ecto_schema_module: ecto_schema_module
                                          },
                                          target: ecto_schema_module})

      authorization_module.can?(subject, :create, ecto_schema_module)

  If the `subject` can create `ecto_schema_module` structs in general, then a second call will check if the specific
  `Ecto.Changeset.t` can be created.

      calcinator_can(:start,
                     compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                     runtime_metadata :: %{action: :create,
                                           calcinator: %Calcinator{
                                             authorizaton_module: module
                                             ecto_schema_module: ecto_schema_module
                                           },
                                           target: %Ecto.Changeset{data: %ecto_schema_module{}}})

      authorization_module.can?(subject, :create, %Ecto.Changeset{data: %ecto_schema_module{}})

  #### `:delete`

  There is only one call to authorize `:delete`.

      calcinator_can(:start,
                     compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                     runtime_metdata :: %{action: :create
                                          calcinator: %Calcinator{
                                            authorizaton_module: module
                                            ecto_schema_module: ecto_schema_module
                                          },
                                          target: %ecto_schema_module{}})

      authorization_module.can?(subject, :delete, %ecto_schema_module{})

  """

  require Logger

  import Calcinator.Instrumenters

  # Macros

  @doc """
  Instruments the given function.

  `event` is the event identifier (usually an atom) that specifies which
  instrumenting function to call in the instrumenter modules. `runtime` is
  metadata to be associated with the event at runtime (e.g., the query being
  issued if the event to instrument is a DB query).

  ## Predefined Events

  ### Examples

      instrument :calcinator_can, %{action: action, calcinator: calcinator, target: target}, fn ->
        ...
      end

  """
  defmacro instrument(event, runtime \\ Macro.escape(%{}), fun) do
    compile = __CALLER__
              |> strip_caller()
              |> Macro.escape()

    quote do
      import Calcinator.Instrument, only: [instrument: 4]

      instrument(
        unquote(event),
        unquote(compile),
        unquote(runtime),
        unquote(fun)
      )
    end
  end

  # Functions

  # For each event in any of the instrumenters, we must generate a
  # clause of the `instrument/4` function. It'll look like this:
  #
  #   def instrument(:my_event, compile, runtime, fun) do
  #     res0 = Inst0.my_event(:start, compile, runtime)
  #     ...
  #
  #     start = :erlang.monotonic_time
  #     try do
  #       fun.()
  #     after
  #       diff = ...
  #       Inst0.my_event(:stop, diff, res0)
  #       ...
  #     end
  #   end
  #
  @doc false
  def instrument(event, compile, runtime, fun)

  for {event, instrumenters} <- app_instrumenters() do
    def instrument(unquote(event), var!(compile), var!(runtime), fun)
        when is_map(var!(compile)) and is_map(var!(runtime)) and is_function(fun, 0) do
      unquote(compile_start_callbacks(instrumenters, event))
      start = :erlang.monotonic_time()

      try do
        fun.()
      after
        var!(diff) = :erlang.monotonic_time() - start
        unquote(compile_stop_callbacks(instrumenters, event))
      end
    end
  end

  # Catch-all clause
  def instrument(event, compile, runtime, fun)
      when is_atom(event) and is_map(compile) and is_map(runtime) and is_function(fun, 0) do
    fun.()
  end

  ## Private Functions

  defp form_fa({name, arity}), do: Atom.to_string(name) <> "/" <> Integer.to_string(arity)
  defp form_fa(nil), do: nil

  # Strips a `Macro.Env` struct, leaving only interesting compile-time metadata.
  @doc false
  @spec strip_caller(Macro.Env.t) :: %{
                                       optional(:application) => atom,
                                       required(:file) => String.t,
                                       required(:line) => non_neg_integer,
                                       required(:function) => String.t | nil,
                                       required(:module) => module
                                     }
  def strip_caller(%Macro.Env{module: mod, function: fun, file: file, line: line}) do
    caller = %{module: mod, function: form_fa(fun), file: file, line: line}

    if app = Application.get_env(:logger, :compile_time_application) do
      Map.put(caller, :application, app)
    else
      caller
    end
  end
end
