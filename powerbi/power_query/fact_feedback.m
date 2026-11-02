let
    Source = Csv.Document(
        CsvFiles{[Name = "fact_feedback.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"feedback_id", type text},
        {"customer_id", type text},
        {"feedback_date", type date},
        {"rating", Int64.Type},
        {"sentiment_label", type text},
        {"sentiment_from_rating", type text},
        {"sentiment_mismatch", Int64.Type},
        {"feedback_theme", type text}
        },
        "en-US")
in
    ChangedTypes
