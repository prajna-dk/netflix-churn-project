let
    Source = Csv.Document(
        CsvFiles{[Name = "sql_winback_candidates.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"customer_id", type text},
        {"churn_date", type date},
        {"churn_reason", type text},
        {"lifetime_value", type number},
        {"minutes_last_90d", Int64.Type},
        {"last_view_date", type date},
        {"last_engagement_level", type text}
        },
        "en-US")
in
    ChangedTypes
