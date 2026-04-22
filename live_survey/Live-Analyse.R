library(tidyverse)
library(googlesheets4)
library(kableExtra)

# ── Config ────────────────────────────────────────────────────────────────────
SHEET_URL <- "https://docs.google.com/spreadsheets/d/1S4JpQFgiT_vIBGyLPv_mAuig9HWKrVdZYaK8oZ5eog8/edit?usp=sharing"
fetch_new_data <- TRUE
# ── Daten laden ───────────────────────────────────────────────────────────────
# Für lokalen Test mit CSV:
# df_raw <- read_csv("Fragebogen Forschungsmethoden.csv")
# Für Live-Daten aus Google Sheets:

if (fetch_new_data) {
  googlesheets4::gs4_auth(
    email = "andrecalerovaldez@gmail.com",
    scopes = "https://www.googleapis.com/auth/spreadsheets.readonly"
  )
  df_raw <- read_sheet(SHEET_URL)
  write_csv(df_raw, "live_survey/Fragebogen Forschungsmethoden.csv") # Backup als CSV
}
df_raw <- read_csv("live_survey/Fragebogen Forschungsmethoden.csv")

# ── Spaltennamen kürzen ───────────────────────────────────────────────────────
names(df_raw) <- c(
  "timestamp", "geschlecht", "alter",
  # Tech-Affinität (ATI, 9 Items)
  "ati1", "ati2", "ati3", "ati4", "ati5",
  "ati6", "ati7", "ati8", "ati9",
  # Big Five (21 Items)
  "bf_e1r", "bf_v1r", "bf_g1",  "bf_n1",  "bf_o1",
  "bf_e2",  "bf_v2",  "bf_g2r", "bf_n2r", "bf_o2",
  "bf_e3r", "bf_v3r", "bf_g3",  "bf_n3",  "bf_o3",
  "bf_e4",  "bf_v4r", "bf_g4",  "bf_n4",  "bf_o4",
  "bf_o5r",
  # Offen
  "lieblingshaustier",
  # Präferenzen (23 Paare)
  "p_starwars_trek", "p_fruehling_herbst", "p_schoki_vanille",
  "p_apple_android", "p_hund_katze", "p_lotr_dune",
  "p_strand_berg", "p_chips_erdnuesse", "p_twilight_fsog",
  "p_hotel_airbnb", "p_wandern_fahrrad", "p_berliner_pfannkuchen",
  "p_kochen_essen", "p_hufflepuff_ravenclaw", "p_kaffee_tee",
  "p_rock_hiphop", "p_tiktok_insta", "p_bier_wein",
  "p_fruehstueck_abendessen", "p_frueh_schlafen",
  "p_marzipan_schoki", "p_party_spieleabend", "p_horror_romkom"
)

# ── Rekodierung Likert-Skalen ─────────────────────────────────────────────────

# Tech-Affinität: 6-stufig
ati_levels <- c(
  "stimmt gar nicht"        = 1,
  "stimmt weitgehend nicht" = 2,
  "stimmt eher nicht"       = 3,
  "stimmt eher"             = 4,
  "stimmt weitgehend"       = 5,
  "stimmt völlig"           = 6
)

# Big Five: 5-stufig
bf_levels <- c(
  "sehr unzutreffend" = 1,
  "eher unzutreffend" = 2,
  "weder noch"        = 3,
  "eher zutreffend"   = 4,
  "sehr zutreffend"   = 5
)

# Präferenzen: 5-stufig (Option 1 = 1, Option 2 = 5)
pref_levels <- c(
  "sicher Option 1" = 1,
  "eher Option 1"   = 2,
  "beides gleich"   = 3,
  "eher Option 2"   = 4,
  "sicher Option 2" = 5
)

# Funktion zur Rekodierung der Skalenwerte
recode_scale <- function(x, levels) {
  unname(levels[x])
}

df <- df_raw %>%
  mutate(
    timestamp  = timestamp,
    geschlecht = as.factor(geschlecht),
    alter      = as.numeric(alter),
    across(starts_with("ati"),  ~ recode_scale(.x, ati_levels)),
    across(starts_with("bf_"),  ~ recode_scale(.x, bf_levels)),
    across(starts_with("p_"),   ~ recode_scale(.x, pref_levels))
  )

# Reverse-Coding (Items mit "r" im Namen: 6 - Wert)
# select: begins with bf_ und ends with r
reverse_items <- str_detect(names(df), "^bf_.*\\dr$")
r_items <- names(df)[reverse_items]
df <- df %>%
  mutate(across(all_of(r_items), ~ 6 - .x))

# ── Skalenwerte berechnen ─────────────────────────────────────────────────────

# Reliabilität
psych::alpha(df %>% select(starts_with("ati"))) # ATI Skala
psych::alpha(df %>% select(starts_with("bf_e"))) # Extraversion
psych::alpha(df %>% select(starts_with("bf_v"))) # Verträglichkeit
psych::alpha(df %>% select(starts_with("bf_g"))) # Gewissenhaftigkeit
psych::alpha(df %>% select(starts_with("bf_n"))) # Neurotizismus
psych::alpha(df %>% select(starts_with("bf_o"))) # Offenheit


# (psych way)
# do one way only
keys.list = list(
  ati_score          = names(df)[str_starts(names(df), "ati")],
  extraversion       = names(df)[str_starts(names(df), "bf_e")],
  vertraeglichkeit   = names(df)[str_starts(names(df), "bf_v")],
  gewissenhaftigkeit = names(df)[str_starts(names(df), "bf_g")],
  neurotizismus      = names(df)[str_starts(names(df), "bf_n")],
  offenheit          = names(df)[str_starts(names(df), "bf_o")]
)

scores <- psych::scoreItems(
  keys = keys.list, df
)

scores$scores
df %>% bind_cols(scores$scores)

# (easy way, works only if everythin is recoded properly)
df <- df %>%
  mutate(
    ati_score          = rowMeans(across(starts_with("ati")), na.rm = TRUE),
    extraversion       = rowMeans(across(starts_with("bf_e")), na.rm = TRUE),
    vertraeglichkeit   = rowMeans(across(starts_with("bf_v")), na.rm = TRUE),
    gewissenhaftigkeit = rowMeans(across(starts_with("bf_g")), na.rm = TRUE),
    neurotizismus      = rowMeans(across(starts_with("bf_n")), na.rm = TRUE),
    offenheit          = rowMeans(across(starts_with("bf_o")), na.rm = TRUE)
  )



# ── Deskriptive Statistik ─────────────────────────────────────────────────────
cat("=== Stichprobe ===\n")
cat("N =", nrow(df), "\n\n")

cat("--- Geschlecht ---\n")
print(table(df$geschlecht))

cat("\n--- Alter ---\n")
cat("M =", round(mean(df$alter, na.rm = TRUE), 1),
    " SD =", round(sd(df$alter, na.rm = TRUE), 1), "\n")

cat("\n--- Tech-Affinität (ATI, 1-6) ---\n")
cat("M =", round(mean(df$ati_score, na.rm = TRUE), 2),
    " SD =", round(sd(df$ati_score, na.rm = TRUE), 2), "\n")

cat("\n--- Big Five (1-5) ---\n")
df %>%
  summarise(across(
    c(extraversion, vertraeglichkeit, gewissenhaftigkeit, neurotizismus, offenheit),
    list(M = ~ round(mean(.x, na.rm = TRUE), 2),
         SD = ~ round(sd(.x,  na.rm = TRUE), 2))
  )) %>%
  print()

# ── Plots ─────────────────────────────────────────────────────────────────────

# Geschlecht
df %>%
  count(geschlecht) %>%
  ggplot(aes(x = geschlecht, y = n, fill = geschlecht)) +
  geom_col(show.legend = FALSE) +
  labs(title = "Geschlechterverteilung", x = "Geschlecht", y = "Anzahl") +
  theme_minimal(base_size = 14)
ggsave("live_survey/geschlecht_plot.png", width = 6, height = 4)


ggstatsplot::gghistostats(
  data = df, x = alter,
  title = "Altersverteilung",
  xlab = "Alter (Jahre)", ylab = "Häufigkeit",
  ggtheme = theme_minimal(base_size = 14)
)
ggsave("live_survey/alter_plot.png", width = 6, height = 4)

# Alter# Aati_scorelter
ggplot(df, aes(x = alter)) +
  geom_histogram(binwidth = 2, fill = "steelblue", color = "white") +
  labs(title = "Altersverteilung", x = "Alter (Jahre)", y = "Häufigkeit") +
  theme_minimal(base_size = 14)
ggsave("live_survey/alter_histogramm.png", width = 6, height = 4)


df %>%
  select(extraversion, vertraeglichkeit, gewissenhaftigkeit, neurotizismus, offenheit) %>%
  pivot_longer(everything(), names_to = "Skala", values_to = "Wert") %>%
  group_by(Skala) %>%
  summarise(M = mean(Wert, na.rm = TRUE),
            SE = sd(Wert, na.rm = TRUE) / sqrt(n())) %>%
ggplot() +
  aes(x=Skala, y=M, colour=Skala) +
  geom_errorbar(aes(ymin = M - SE, ymax = M + SE), width = 0.2) +
  geom_point(size = 3) +
  geom_hline(yintercept = 3, linetype = "dashed", color = "gray") +
  coord_flip() +
  scale_y_continuous(limits = c(1, 5), breaks = 1:5) +
  theme_bw()
ggsave("live_survey/bigfive_plot.png", width = 6, height = 4)

# Präferenzen: Balkendiagramm für alle Paare
pref_cols <- names(df)[str_starts(names(df), "p_")]
pref_labels <- c(
  "Star Wars vs Trek", "Frühling vs Herbst", "Schoki vs Vanille",
  "Apple vs Android", "Hund vs Katze", "LotR vs Dune",
  "Strand vs Berge", "Chips vs Erdnüsse", "Twilight vs FSoG",
  "Hotel vs AirBnB", "Wandern vs Fahrrad", "Berliner vs Pfannkuchen",
  "Kochen vs Essen gehen", "Hufflepuff vs Ravenclaw", "Kaffee vs Tee",
  "Rock vs HipHop", "TikTok vs Insta", "Bier vs Wein",
  "Frühstück vs Abendessen", "Früh auf vs Lang schlafen",
  "Marzipan vs Schoki", "Party vs Spieleabend", "Horror vs RomKom"
)

df %>%
  select(all_of(pref_cols)) %>%
  pivot_longer(everything(), names_to = "frage", values_to = "wert") %>%
  mutate(frage = factor(frage, levels = pref_cols, labels = pref_labels)) %>%
  ggplot(aes(x = wert)) +
  geom_bar(fill = "steelblue") +
  facet_wrap(~frage, ncol = 4) +
  scale_x_continuous(
    breaks = 1:5,
    labels = c("1\n(Opt.1)", "2", "3\n(gleich)", "4", "5\n(Opt.2)")
  ) +
  labs(title = "Präferenzen", x = NULL, y = "Anzahl") +
  theme_minimal(base_size = 10)

# Attach variable.labels attr for semantic_differential_plot
# Format: "[left|right]" extracted from "Option1 vs Option2"
df$id <- seq_len(nrow(df))
pref_var_labels <- paste0("[", str_replace(pref_labels, " vs ", "|"), "]")
all_labels <- setNames(rep(NA_character_, ncol(df)), names(df))
all_labels[pref_cols] <- pref_var_labels
attr(df, "variable.labels") <- all_labels






semantic_differential_plot <- function(data,
                                       responses = data,
                                       variable_prefix = "semantic",
                                       differential_range = 2,
                                       recode_from_center = TRUE,
                                       conf_level = 0.95,
                                       plot_title = "Semantisches Differenzial nach Kategorie",
                                       y_label = "Tendenz",
                                       caption = "Mittelwert und 95% Konfidenzintervall (bootstrapped)") {
  # Pakete prüfen
  required_packages <- c(
    "dplyr", "tidyr", "stringr", "ggplot2", "tibble"
  )

  missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_packages) > 0) {
    stop(
      "Folgende Pakete fehlen: ",
      paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  # Kurzreferenzen
  dplyr <- asNamespace("dplyr")
  tidyr <- asNamespace("tidyr")
  stringr <- asNamespace("stringr")
  ggplot2 <- asNamespace("ggplot2")
  tibble <- asNamespace("tibble")

  # variable labels auslesen
  variable_labels <- attr(data, "variable.labels")

  if (is.null(variable_labels)) {
    stop("Das Objekt 'data' hat keine Attribute 'variable.labels'.", call. = FALSE)
  }

  # Codebook erzeugen
  codebook <- tibble::tibble(
    name = names(data),
    label = unname(variable_labels)
  )

  # relevante Variablen filtern
  semantic_labels <- codebook |>
    dplyr::filter(stringr::str_starts(name, variable_prefix)) |>
    dplyr::mutate(
      label = stringr::str_extract(label, "\\[(.*)\\]")
    ) |>
    dplyr::mutate(
      label = stringr::str_sub(label, start = 2, end = -2)
    ) |>
    tidyr::separate(
      col = label,
      into = c("left", "right"),
      sep = "\\|",
      remove = FALSE
    )

  if (nrow(semantic_labels) == 0) {
    stop("Keine Variablen mit dem angegebenen Prefix gefunden.", call. = FALSE)
  }

  # ID-Spalte prüfen
  if (!"id" %in% names(responses)) {
    stop("In 'responses' fehlt eine Spalte namens 'id'.", call. = FALSE)
  }

  # relevante Antwortdaten auswählen
  semantic_var_names <- semantic_labels$name

  missing_response_vars <- setdiff(semantic_var_names, names(responses))
  if (length(missing_response_vars) > 0) {
    stop(
      "Diese Variablen fehlen in 'responses': ",
      paste(missing_response_vars, collapse = ", "),
      call. = FALSE
    )
  }

  semantic_variables <- responses |>
    dplyr::select(id, dplyr::all_of(semantic_var_names)) |>
    stats::setNames(c("id", semantic_labels$left)) |>
    tidyr::pivot_longer(cols = -id, names_to = "name", values_to = "value") |>
    dplyr::mutate(
      value = as.numeric(as.character(value))
    )

  # optional: 1:5 -> -2:2 umkodieren
  if (isTRUE(recode_from_center)) {
    semantic_variables <- semantic_variables |>
      dplyr::mutate(value = value - (differential_range + 1))
  }

  # Mittelwerte berechnen
  semantic_variables <- semantic_variables |>
    dplyr::group_by(name) |>
    dplyr::mutate(mean_value = mean(value, na.rm = TRUE)) |>
    dplyr::ungroup()

  # Reihenfolge nach Mittelwert
  semantic_labels_ordered <- semantic_labels |>
    dplyr::left_join(
      semantic_variables |>
        dplyr::select(name, mean_value) |>
        dplyr::distinct(),
      by = c("left" = "name")
    ) |>
    dplyr::arrange(dplyr::desc(mean_value))

  # Plot-Daten vorbereiten
  plot_data <- semantic_variables |>
    dplyr::mutate(
      name_num = as.numeric(
        factor(name, levels = semantic_labels_ordered$left, ordered = TRUE)
      )
    )

  # Plot erzeugen
  p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = name_num, y = value)) +
    ggplot2::stat_summary(
      fun.data = "mean_cl_boot",
      geom = "errorbar",
      width = 0.3,
      fun.args = list(conf.int = conf_level)
    ) +
    ggplot2::stat_summary(
      fun = mean,
      geom = "point"
    ) +
    ggplot2::stat_summary(
      fun = mean,
      geom = "line",
      ggplot2::aes(group = 1)
    ) +
    ggplot2::scale_y_continuous(
      limits = c(-differential_range, differential_range)
    ) +
    ggplot2::scale_x_continuous(
      name = NULL,
      limits = c(0.5, length(semantic_labels_ordered$left) + 0.5),
      expand = c(0, 0),
      breaks = seq_along(semantic_labels_ordered$left),
      minor_breaks = NULL,
      labels = semantic_labels_ordered$left,
      sec.axis = ggplot2::dup_axis(
        labels = semantic_labels_ordered$right,
        name = NULL
      )
    ) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = plot_title,
      y = y_label,
      caption = caption
    )

  # alles zurückgeben
  list(
    codebook = codebook,
    semantic_labels = semantic_labels,
    semantic_variables = semantic_variables,
    semantic_labels_ordered = semantic_labels_ordered,
    plot = p
  )
}

result <- semantic_differential_plot(
  data = df,
  responses = df,
  variable_prefix = "p_",
  differential_range = 2,
  recode_from_center = TRUE
)

result$plot
ggsave("live_survey/praeferenzen_plot.png", width = 8, height = 10)
