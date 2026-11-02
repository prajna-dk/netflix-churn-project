let
    Source = Csv.Document(
        CsvFiles{[Name = "model_campaign_scenarios.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"campaign_size", type text},
        {"targeting", type text},
        {"contacts", Int64.Type},
        {"churn_rate_in_group", type number},
        {"churners_reached", Int64.Type},
        {"customers_saved", Int64.Type},
        {"value_saved", Int64.Type},
        {"cost", Int64.Type},
        {"net_value", Int64.Type}
        },
        "en-US")
in
    ChangedTypes
