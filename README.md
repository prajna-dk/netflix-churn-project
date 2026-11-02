# Netflix Customer Churn Intelligence Project

End-to-end analytics project: data cleaning (Python), database and 37 SQL business questions (MySQL),
exploratory analysis, churn model, segmentation, customer value, text themes, and a Power BI dashboard.

**Tools (all free):** Google Colab, MySQL Community Server + Workbench, Power BI Desktop, Google Drive for Desktop.
**Analysis date (as-of):** 2026-06-30. The data is synthetic.

## Folder structure
| Folder | Contents |
|---|---|
| `data/raw` | Original CSVs from the zip, never edited |
| `data/clean` | Cleaned CSVs (MySQL loads these) |
| `data/sql_exports` | Result CSVs exported from MySQL Workbench |
| `data/features` | Customer-level feature tables for the model |
| `data/model_outputs` | Predictions, segments, customer value, text themes |
| `data/bi_ready` | The only folder Power BI reads |
| `database` | Numbered `.sql` scripts |
| `notebooks` | Colab notebooks 01 to 15 |
| `src` | Helper code (`cleaning_helpers.py`, `features.py`) |
| `models` | Saved models |
| `reports` | Charts, evaluation report, final report, PDF |
| `docs` | Project log, audits, cleaning log, feature and BI dictionaries |
| `powerbi` | `.pbix`, theme, Power Query scripts, DAX measures |

## Run order (to rebuild everything from the zip file)
| Step | Tool | File | Produces |
|---|---|---|---|
| 1 | Colab | `notebooks/01_setup_and_audit` | Folders, raw data, audit |
| 2-3 | Colab | `02_cleaning_part1`, `03_cleaning_part2` | `data/clean/*.csv` |
| 4 | MySQL | `database/01..04_*.sql` (replace the folder placeholder once in `02_load_data.sql`) | Database `netflix_churn` |
| 5-7 | MySQL | `database/05..07_*.sql` | Answers to Q1-Q37 and exports in `data/sql_exports` |
| 8 | Colab | `08_eda` | Charts, `reports/eda_churn_by_group.csv` |
| 9 | Colab | `09_feature_engineering` | `data/features/*` |
| 10 | Colab | `10_churn_model` | Model, `churn_predictions.csv` |
| 11 | Colab | `11_segmentation` | `customer_segments.csv`, `segment_profile.csv` |
| 12 | Colab | `12_value_and_evaluation` | `customer_value.csv`, evaluation report |
| 13 | Colab | `13_text_themes_and_bi_tables` | Text themes, `data/bi_ready/*` |
| 14 | Colab + Power BI | `14_powerbi_setup_files`, then the `.pbix` | Power Query scripts, DAX, pages 1-3 |
| 15 | Colab + Power BI | `15_final_deliverables`, then the `.pbix` | Pages 4-7, PDF, report, README |

Every notebook starts with a small cell that finds `PROJECT_ROOT.marker` by walking up the folders, so the project works wherever it is copied.

## Refreshing the dashboard
Open `powerbi/netflix_churn_dashboard.pbix`, set the `DataFolder` parameter to your `data/bi_ready` folder
(Home > Transform data > Edit parameters), then Home > Refresh.

## Honest limits
Synthetic data; weak model signal (AUC about 0.57); churn dates only from 2025-10; payments capped at 15 per customer; templated text.
See `reports/Final_Project_Report.md`.
