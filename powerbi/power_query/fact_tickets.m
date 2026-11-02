let
    Source = Csv.Document(
        CsvFiles{[Name = "fact_tickets.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"ticket_id", type text},
        {"customer_id", type text},
        {"ticket_date", type date},
        {"issue_category", type text},
        {"issue_subcategory", type text},
        {"priority", type text},
        {"ticket_status", type text},
        {"resolution_time_hours", type number},
        {"customer_satisfaction_score", type number},
        {"text_theme", type text}
        },
        "en-US")
in
    ChangedTypes
