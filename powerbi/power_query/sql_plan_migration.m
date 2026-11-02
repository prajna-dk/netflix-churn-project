let
    Source = Csv.Document(
        CsvFiles{[Name = "sql_plan_migration.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"migration_path", type text},
        {"direction", type text},
        {"customers", Int64.Type},
        {"churned_customers", Int64.Type},
        {"churn_rate_pct", type number}
        },
        "en-US")
in
    ChangedTypes
