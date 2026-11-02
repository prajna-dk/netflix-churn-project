let
    Source = Csv.Document(
        CsvFiles{[Name = "sql_cohort_retention.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"cohort_month", type text},
        {"cohort_size", Int64.Type},
        {"retained_1m_pct", type number},
        {"retained_3m_pct", type number},
        {"retained_6m_pct", type number},
        {"still_active_today_pct", type number}
        },
        "en-US")
in
    ChangedTypes
