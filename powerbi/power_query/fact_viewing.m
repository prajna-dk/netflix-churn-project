let
    Source = Csv.Document(
        CsvFiles{[Name = "fact_viewing.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"viewing_id", type text},
        {"customer_id", type text},
        {"content_id", type text},
        {"viewing_date", type date},
        {"watch_duration_minutes", Int64.Type},
        {"completion_percentage", type number},
        {"device_type", type text},
        {"login_location", type text},
        {"session_duration_minutes", Int64.Type}
        },
        "en-US")
in
    ChangedTypes
