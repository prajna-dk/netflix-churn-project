let
    Source = Csv.Document(
        CsvFiles{[Name = "model_text_theme_summary.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"source", type text},
        {"theme_name", type text},
        {"items", Int64.Type},
        {"customers", Int64.Type},
        {"avg_rating", type number},
        {"negative_share", type number},
        {"churn_rate_pct", type number},
        {"avg_csat", type number},
        {"avg_resolution_hours", type number}
        },
        "en-US")
in
    ChangedTypes
