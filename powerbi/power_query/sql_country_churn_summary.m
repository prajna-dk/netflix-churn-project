let
    Source = Csv.Document(
        CsvFiles{[Name = "sql_country_churn_summary.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"country", type text},
        {"total_customers", Int64.Type},
        {"churned_customers", Int64.Type},
        {"churn_rate_pct", type number},
        {"avg_lifetime_value_churned", type number},
        {"top_churn_reason", type text},
        {"customers_with_top_reason", Int64.Type}
        },
        "en-US")
in
    ChangedTypes
