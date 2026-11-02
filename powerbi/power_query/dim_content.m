let
    Source = Csv.Document(
        CsvFiles{[Name = "dim_content.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"content_id", type text},
        {"title", type text},
        {"content_type", type text},
        {"genre", type text},
        {"release_year", Int64.Type},
        {"duration_minutes", Int64.Type},
        {"content_language", type text},
        {"production_country", type text},
        {"maturity_rating", type text}
        },
        "en-US")
in
    ChangedTypes
