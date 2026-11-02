let
    Source = Csv.Document(
        CsvFiles{[Name = "model_lift_by_decile.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"risk_decile", Int64.Type},
        {"customers", Int64.Type},
        {"actual_churn_rate", type number},
        {"avg_predicted", type number},
        {"lift_vs_average", type number}
        },
        "en-US")
in
    ChangedTypes
