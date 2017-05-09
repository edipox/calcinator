%{
  configs: [
    %{
      checks: [
        {Credo.Check.Consistency.MultiAliasImportRequireUse, false},
        {
          Credo.Check.Design.AliasUsage,
          excluded_lastnames: ~w(Controller Sandbox),
          excluded_namespaces: ~w(Faker Meta)
        },
        {Credo.Check.Readability.MaxLineLength, priority: :low, max_length: 120},
        {Credo.Check.Refactor.Nesting, max_nesting: 3}
      ],
      files: %{
        # add "test/" so tests don't get too gnarly and to remain consistent with ruby projects that run rubocop on
        # "spec/"
        included: ["lib/", "test/"]
      },
      name: "default",
      strict: true
    }
  ]
}
