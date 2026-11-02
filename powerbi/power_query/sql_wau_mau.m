let
    Source = Csv.Document(
        CsvFiles{[Name = "sql_wau_mau.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"month", type text},
        {"mau", Int64.Type},
        {"avg_wau", type number},
        {"weeks_counted", Int64.Type},
        {"stickiness_wau_over_mau", type number}
        },
        "en-US")
in
    ChangedTypes
