%{
  configs: [
    %{
      checks: [
        {Credo.Check.Design.AliasUsage, excluded_lastnames: ~w(Controller), excluded_namespaces: ~w(Meta)},
        {Credo.Check.Readability.MaxLineLength, priority: :low, max_length: 120}
      ],
      files: %{
        # add "test/" so tests don't get too gnarly and to remain consistent with ruby projects that run rubocop on
        # "spec/"
        included: ["lib/", "test/"]
      },
      name: "default"
    }
  ]
}
