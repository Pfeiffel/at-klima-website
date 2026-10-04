# ------------------------------------------------------------------
# Gemeinsame Basis für alle Seiten
#
# Jede .qmd-Datei lädt diese Datei mit:
#     source("R/setup.R")
#
# Hier stehen Farben, Theme und Datenzugriff EINMAL. Wenn du das
# Aussehen änderst, änderst du nur diese Datei - und alle Grafiken
# auf der ganzen Website ziehen nach.
#
# Bewusst KEIN sf / terra / elevatr: Diese Pakete brauchen
# Systembibliotheken (GDAL, PROJ) und sind der häufigste Grund,
# warum eine Installation scheitert. Die Klimaseiten kommen ohne aus.
# ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(ggplot2)
  library(httr)
})

# ---------------------------------------------------------- FARBEN

# Sequenziell (Menge): ein Farbton, hell nach dunkel
SEQ_LOW   <- "#cde2fb"
SEQ_MID   <- "#2a78d6"
SEQ_HIGH  <- "#0d366b"

# Divergierend (Vorzeichen): zwei Pole, neutrale Mitte
DIV_LOW   <- "#2a78d6"
DIV_MID   <- "#f0efec"
DIV_HIGH  <- "#d03b3b"

# Kategorial: feste Reihenfolge, auf Farbsehschwäche geprüft.
# Immer von vorne vergeben, nie umsortieren.
KATEGORIAL <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100",
                "#e87ba4", "#008300", "#4a3aa7", "#e34948")

# Klimastreifen
STRIPES <- c("#08306b", "#4292c6", "#f7f7f7", "#ef6548", "#7f0000")

# Temperaturskala kalt -> heiß, für Balken und Punkte
KALT  <- "#2a78d6"
MILD  <- "#86b6ef"
WARM  <- "#ef6548"
HEISS <- "#7f0000"
GRUEN <- "#1baf7a"

INK      <- "#0b0b0b"
INK_2    <- "#52514e"
INK_MUT  <- "#898781"
SURFACE  <- "#fcfcfb"
GRID     <- "#e1e0d9"

# ---------------------------------------------------------- THEME

theme_at <- function(base_size = 13) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(
      plot.title       = element_text(face = "bold", size = base_size * 1.25,
                                      color = INK, margin = margin(b = 4)),
      plot.subtitle    = element_text(size = base_size * 0.9, color = INK_2,
                                      margin = margin(b = 14)),
      plot.caption     = element_text(size = base_size * 0.65, color = INK_MUT,
                                      hjust = 0, margin = margin(t = 12)),
      axis.text        = element_text(size = base_size * 0.78, color = INK_MUT),
      axis.title       = element_text(size = base_size * 0.78, color = INK_2),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = GRID, linewidth = 0.4),
      plot.background  = element_rect(fill = SURFACE, color = NA),
      panel.background = element_rect(fill = SURFACE, color = NA),
      legend.title     = element_text(size = base_size * 0.78, color = INK_2),
      legend.text      = element_text(size = base_size * 0.78, color = INK_MUT),
      legend.position  = "top",
      legend.justification = "left",
      strip.text       = element_text(face = "bold", size = base_size * 0.82,
                                      color = INK_2),
      plot.margin      = margin(14, 14, 10, 14)
    )
}

theme_set(theme_at())

QUELLE_GEO  <- "Datenquelle: GeoSphere Austria, HISTALP"
QUELLE_TAG  <- "Datenquelle: GeoSphere Austria, Datensatz klima-v2-1d"
QUELLE_STAT <- "Datenquelle: Statistik Austria – data.statistik.gv.at (CC BY 4.0)"

MONATE <- c("Jän", "Feb", "Mär", "Apr", "Mai", "Jun",
            "Jul", "Aug", "Sep", "Okt", "Nov", "Dez")

# Tag im Jahr (1-366) in ein lesbares Datum übersetzen
tag_label <- function(t) {
  format(as.Date(t - 1, origin = "2001-01-01"), "%d. %b")
}

MONATSACHSE <- list(
  breaks = c(1, 60, 121, 182, 244, 305, 365),
  labels = c("Jän", "Mär", "Mai", "Jul", "Sep", "Nov", "Dez")
)

# ------------------------------------------- GEOSPHERE: JAHRESDATEN
#
# HISTALP ist eine homogenisierte Sammlung von Messreihen für den
# Alpenraum - also bereinigt um Stationsverlegungen und Gerätewechsel.
# Nur deshalb sind Vergleiche über 270 Jahre überhaupt zulässig.

histalp_holen <- function(station_ids, parameter = "T01",
                          von = "1753-01-01T00:00",
                          bis = "2021-12-31T00:00") {
  antwort <- httr::GET(
    "https://dataset.api.hub.geosphere.at/v1/station/historical/histalp-v1-1y",
    query = list(
      parameters    = paste(parameter, collapse = ","),
      start         = von,
      end           = bis,
      station_ids   = paste(station_ids, collapse = ","),
      output_format = "csv"))

  if (httr::status_code(antwort) != 200) {
    stop("GeoSphere-API antwortet mit Status ", httr::status_code(antwort),
         ":\n", httr::content(antwort, "text", encoding = "UTF-8"))
  }
  readr::read_csv(httr::content(antwort, "text", encoding = "UTF-8"),
                  show_col_types = FALSE)
}

HISTALP_STATIONEN <- tibble::tribble(
  ~station_id, ~station,            ~hoehe,
  53L,         "Graz",                 377,
  59L,         "Innsbruck",            609,
  67L,         "Kremsmünster",         382,
  122L,        "Salzburg",             450,
  127L,        "Sonnblick",           3105,
  152L,        "Wien-Hohe Warte",      209
)

# -------------------------------------------- GEOSPHERE: TAGESDATEN
#
# ACHTUNG: Die Stations-IDs sind hier ANDERE als bei HISTALP.
# Wien ist in klima-v2-1d die 105, in HISTALP die 152.
#
# Parameter: tl (Mittel), tlmax, tlmin, rr (Niederschlag), sh (Schnee)

klima_tag <- function(station_id, parameter,
                      von = "1900-01-01T00:00",
                      bis = "2025-12-31T00:00") {
  antwort <- httr::GET(
    "https://dataset.api.hub.geosphere.at/v1/station/historical/klima-v2-1d",
    query = list(
      parameters    = paste(parameter, collapse = ","),
      start         = von,
      end           = bis,
      station_ids   = as.character(station_id),
      output_format = "csv"))

  if (httr::status_code(antwort) != 200) {
    stop("GeoSphere-API antwortet mit Status ", httr::status_code(antwort),
         ":\n", httr::content(antwort, "text", encoding = "UTF-8"))
  }
  readr::read_csv(httr::content(antwort, "text", encoding = "UTF-8"),
                  show_col_types = FALSE)
}

KLIMA_STATIONEN <- tibble::tribble(
  ~station_id, ~station,            ~hoehe,
  30L,         "Graz",                 366,
  39L,         "Innsbruck",            578,
  105L,        "Wien-Hohe Warte",      198,
  131L,        "Salzburg",             430,
  204L,        "Kremsmünster",         383,
  213L,        "Sonnblick",           3109
)

# Welche Parameter der Datensatz wirklich anbietet - zum Nachsehen,
# falls ein Abruf mit "unknown parameter" scheitert:
#
#   GET("https://dataset.api.hub.geosphere.at/v1/station/historical/
#        klima-v2-1d/metadata") |> content("parsed") |>
#     pluck("parameters") |> map_chr("name")

# ------------------------------------- STATISTIK AUSTRIA (ungenutzt)
#
# Diese Helfer brauchen keine zusätzlichen Pakete und stehen bereit,
# falls du später Seiten zu Sterblichkeit, Wohnen oder Tourismus
# ergänzen willst. Eigenheiten des Portals, hier einmal gelöst:
#   * Semikolon trennt die Spalten
#   * Komma ist das Dezimaltrennzeichen
#   * Codes tragen Präfixe ("JAHR-2010") - die Ziffern holen wir per
#     Regex, weil Statistik Austria die Präfixe gelegentlich ändert
#   * Klartextnamen stehen in eigenen Codelisten-Dateien

OGD_BASIS <- "https://data.statistik.gv.at/data/"

OGD <- c(
  sterbefaelle    = "OGD_gest_kalwo_GEST_KALWOCHE_100",
  tourismus       = "OGD_touextsai_Tour_HKL_1",
  haeuserpreise   = "OGD_hpi2010_HPI_10_1",
  tariflohn       = "OGD_tli16nace20_TLI_110",
  baubewilligung  = "OGD_bewwohn303_BB303_1",
  fertilitaet     = "OGD_ind002fertilrat_HVD_FERTILRATE_1",
  lebenserwartung = "OGD_ind003_HVD_IND_1"
)

ogd <- function(schluessel, dimension = NULL) {
  pfad <- paste0(OGD_BASIS, OGD[[schluessel]],
                 if (!is.null(dimension)) paste0("_", dimension) else "",
                 ".csv")
  readr::read_delim(pfad, delim = ";",
                    locale = readr::locale(decimal_mark = ",",
                                           grouping_mark = "."),
                    show_col_types = FALSE)
}

codeliste <- function(schluessel, dimension) {
  ogd(schluessel, dimension) |> dplyr::select(code, name)
}

ziffern <- function(x) stringr::str_extract(as.character(x), "[0-9]+$")

finde_code <- function(cl, muster) {
  treffer <- cl |> dplyr::filter(stringr::str_detect(
    name, stringr::regex(muster, ignore_case = TRUE)))
  if (nrow(treffer) == 0) NA_character_ else treffer$code[1]
}

benenne <- function(df, spalte, schluessel, dimension, neu) {
  cl <- codeliste(schluessel, dimension)
  names(cl) <- c(spalte, neu)
  dplyr::left_join(df, cl, by = spalte)
}
