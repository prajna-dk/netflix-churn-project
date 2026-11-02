let
    Source = Csv.Document(
        CsvFiles{[Name = "dim_plan.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"plan_id", type text},
        {"plan_name", type text},
        {"monthly_price", type number},
        {"video_quality", type text},
        {"max_devices", Int64.Type},
        {"advertisements", type text}
        },
        "en-US")
in
    ChangedTypes
