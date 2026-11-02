let
    Source = Csv.Document(
        CsvFiles{[Name = "sql_outreach_list.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"customer_id", type text},
        {"country", type text},
        {"plan_name", type text},
        {"negative_feedbacks_matched", Int64.Type},
        {"trigger_types", type text},
        {"latest_negative_feedback", type date}
        },
        "en-US")
in
    ChangedTypes
