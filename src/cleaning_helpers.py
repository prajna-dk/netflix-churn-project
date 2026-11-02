"""Reusable cleaning helpers for the Netflix project."""
import pandas as pd

# canonical name -> every spelling we found in the raw data (all lower case)
COUNTRY_ALIASES = {
    "United States":        ["united states", "usa", "us", "u.s.a", "u.s.", "america"],
    "India":                ["india", "in", "bharat"],
    "United Kingdom":       ["united kingdom", "uk", "u.k.", "britain", "great britain"],
    "Canada":               ["canada", "ca"],
    "Brazil":               ["brazil", "br"],
    "Germany":              ["germany", "de"],
    "France":               ["france", "fr"],
    "Mexico":               ["mexico", "mx"],
    "Japan":                ["japan", "jp"],
    "Philippines":          ["philippines", "ph"],
    "Indonesia":            ["indonesia", "id"],
    "Italy":                ["italy", "it"],
    "Nigeria":              ["nigeria", "ng"],
    "Spain":                ["spain", "es"],
    "South Africa":         ["south africa", "za"],
    "Australia":            ["australia", "au"],
    "South Korea":          ["south korea", "kr", "s. korea", "s.korea"],
    "Argentina":            ["argentina", "ar"],
    "Poland":               ["poland", "pl"],
    "United Arab Emirates": ["united arab emirates", "uae", "u.a.e", "ae"],
}

DEVICE_ALIASES = {
    "Smart TV":       ["smart tv", "smarttv", "tv"],
    "Mobile":         ["mobile", "smartphone", "phone"],
    "Laptop":         ["laptop", "desktop", "pc"],
    "Tablet":         ["tablet", "ipad"],
    "Gaming Console": ["gaming console", "console", "playstation/xbox"],
}

def _build_lookup(aliases):
    """Turn {'India': ['india','in']} into {'india': 'India', 'in': 'India'}."""
    return {spelling: canonical for canonical, spellings in aliases.items() for spelling in spellings}

COUNTRY_LOOKUP = _build_lookup(COUNTRY_ALIASES)
DEVICE_LOOKUP = _build_lookup(DEVICE_ALIASES)

def standardize(series, lookup):
    """Lower-case + strip each value, then translate it. Blanks stay blank. Unknown spellings stay as they were."""
    cleaned = series.astype("string").str.strip().str.lower()
    translated = cleaned.map(lookup)
    return translated.fillna(series.astype("string").str.strip())

def standardize_country(series):
    return standardize(series, COUNTRY_LOOKUP)

def standardize_device(series):
    return standardize(series, DEVICE_LOOKUP)

def save_clean(df, name, clean_folder):
    """Save a cleaned table. Dates are written as YYYY-MM-DD, blanks stay blank (MySQL turns them into NULL)."""
    path = clean_folder / f"{name}.csv"
    df.to_csv(path, index=False, date_format="%Y-%m-%d")
    print(f"saved {path.name:28s} rows={len(df):>7,}  columns={df.shape[1]}")
    return path
