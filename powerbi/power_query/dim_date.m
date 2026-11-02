let
    Source = Csv.Document(
        CsvFiles{[Name = "dim_date.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"date", type date},
        {"year", Int64.Type},
        {"quarter", type text},
        {"year_quarter", type text},
        {"month_number", Int64.Type},
        {"month_name", type text},
        {"year_month", type text},
        {"month_start", type date},
        {"week_start", type date},
        {"day_name", type text},
        {"is_weekend", Int64.Type},
        {"is_after_as_of", Int64.Type}
        },
        "en-US")
in
    ChangedTypes
