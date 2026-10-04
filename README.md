# Österreich im Klimawandel — Quarto-Website

Eine statische Website mit zwei Klimaseiten, gebaut mit
[Quarto](https://quarto.org) und R.

Es liegen **keine Datendateien im Repository** — alles wird beim Rendern direkt
von GeoSphere Austria geladen.

## Was du brauchst

1. **R** (ab 4.2) — [cran.r-project.org](https://cran.r-project.org)
2. **Quarto** — [quarto.org/docs/get-started](https://quarto.org/docs/get-started/)
   (RStudio bringt Quarto bereits mit, dann entfällt dieser Schritt)
3. Drei R-Pakete:

```r
install.packages(c("tidyverse", "httr", "knitr"))
```

Mehr nicht. Bewusst **kein `sf`, `terra` oder `elevatr`** — die brauchen
Systembibliotheken wie GDAL und sind der häufigste Grund, warum eine
Installation scheitert.

## Lokal bauen

```bash
quarto preview      # öffnet die Seite im Browser, baut bei jeder Änderung neu
quarto render       # baut einmal komplett nach _site/
```

Der **erste** Durchlauf dauert ein paar Minuten, weil über hunderttausend
Tageswerte geladen werden. Danach greift Quartos `freeze`-Mechanismus und jeder
weitere Lauf geht in Sekunden.

## Online stellen

Der mitgelieferte GitHub-Workflow veröffentlicht automatisch auf GitHub Pages.

**Einmalig einrichten:**

1. In `_quarto.yml` die Zeile `site-url` auf deine Adresse ändern
2. Repository auf GitHub pushen
3. Dort unter *Settings → Pages* bei **Source** den Eintrag
   **GitHub Actions** wählen

**Danach bei jeder Änderung:**

```bash
quarto render        # lokal rendern
git add .            # WICHTIG: inklusive _freeze/
git commit -m "Aktualisiert"
git push
```

Nach ein bis zwei Minuten ist die Seite unter
`https://DEIN-NAME.github.io/REPO-NAME` erreichbar.

### Warum lokal rendern und nicht in der Cloud?

Weil der Workflow dadurch **kein R installieren muss**. Durch `freeze: auto` in
`_quarto.yml` liegen die berechneten Ergebnisse im Ordner `_freeze/`. Wird der
mitcommittet, setzt Quarto daraus die Seiten zusammen, ohne den Code erneut
auszuführen.

Der Unterschied ist erheblich: unter einer Minute statt zwanzig, und der Bau
scheitert nicht, wenn die API gerade nicht erreichbar ist.

**`_freeze/` gehört also ins Repository** — es steht bewusst nicht in der
`.gitignore`.

## Aufbau

```
at-klima-website/
├── _quarto.yml              Seitenkonfiguration, Navigation, Format
├── styles.scss              Farben, Schriften, Abstände
├── styles.css               Feinheiten
├── R/setup.R                Theme, Farben, Datenzugriff — zentral
├── index.qmd                Startseite
├── klima.qmd                270 Jahre, HISTALP-Jahreswerte
├── extreme.qmd              Hitze und Frost, Tagesdaten
├── ueber.qmd                Quellen und Methodik
└── .github/workflows/       Automatische Veröffentlichung
```

## Eine andere Messstation nehmen

In `extreme.qmd` die Zeile `WIEN <- 105` ändern. Die IDs stehen in `R/setup.R`
unter `KLIMA_STATIONEN`:

| ID | Station | Seehöhe |
|---|---|---|
| 30 | Graz | 366 m |
| 39 | Innsbruck | 578 m |
| 105 | Wien-Hohe Warte | 198 m |
| 131 | Salzburg | 430 m |
| 204 | Kremsmünster | 383 m |
| 213 | Sonnblick | 3.109 m |

**Achtung:** Die IDs der beiden Datensätze sind verschieden. Wien ist in
`klima-v2-1d` die 105, in HISTALP die 152. Die HISTALP-Liste steht separat
unter `HISTALP_STATIONEN`.

## Eine neue Seite hinzufügen

1. `meinthema.qmd` anlegen, oben einen YAML-Kopf mit `title:` setzen
2. Erster Chunk: `source("R/setup.R")`
3. In `_quarto.yml` unter `navbar: left:` einen Eintrag ergänzen
4. Für die Grafiken `theme_at()` und die Farbkonstanten aus `setup.R`
   verwenden — dann passt die neue Seite automatisch zum Rest

In `R/setup.R` stehen unten bereits Helfer für **Statistik Austria** bereit
(`ogd()`, `ziffern()`, `benenne()`). Sie brauchen keine zusätzlichen Pakete.
Damit lassen sich Seiten zu Sterblichkeit, Wohnen oder Tourismus ergänzen,
ohne an der Infrastruktur etwas zu ändern.

## Fallstricke der Datenquellen

- Die **Stations-IDs unterscheiden sich je Datensatz** (siehe oben). Das ist
  der häufigste Fehler.
- `klima-v2-1d` ist **nicht homogenisiert**. Für Vergleiche über 200 Jahre
  HISTALP nehmen.
- Jahre mit Messlücken müssen aussortiert werden, sonst täuschen sie bei
  Zählungen wie „Hitzetage pro Jahr" einen Trend vor.
- Beim Verknüpfen auf Namensgleichheit achten: Hat die Rohtabelle eine Spalte,
  die auch in der Nachschlagetabelle vorkommt, macht `left_join()` daraus `.x`
  und `.y` — die ursprüngliche Spalte gibt es dann nicht mehr.
- Falls ein Abruf mit *unknown parameter* scheitert, liefert die API selbst die
  gültige Liste:

```r
GET(paste0("https://dataset.api.hub.geosphere.at/v1/",
           "station/historical/klima-v2-1d/metadata")) |>
  content("parsed") |> pluck("parameters") |> map_chr("name")
```

## Lizenz

Code: frei verwendbar. Daten: GeoSphere Austria, CC BY 4.0 — Quellenangabe
erforderlich.
