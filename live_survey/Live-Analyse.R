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
  # Tech-Affinität (ATUH, 9 Items)
  "atuh1", "atuh2", "atuh3", "atuh4", "atuh5",
  "atuh6", "atuh7", "atuh8", "atuh9",
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
atuh_levels <- c(
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

recode_scale <- function(x, levels) {
  unname(levels[x])
}

df <- df_raw %>%
  mutate(
    timestamp  = timestamp,
    geschlecht = as.factor(geschlecht),
    alter      = as.numeric(alter),
    across(starts_with("atuh"), ~ recode_scale(.x, atuh_levels)),
    across(starts_with("bf_"),  ~ recode_scale(.x, bf_levels)),
    across(starts_with("p_"),   ~ recode_scale(.x, pref_levels))
  )

# Reverse-Coding (Items mit "r" im Namen: 6 - Wert)
r_items <- names(df)[str_detect(names(df), "^bf_.*\\dr$")]
df <- df %>%
  mutate(across(all_of(r_items), ~ 6 - .x))

# ── Skalenwerte berechnen ─────────────────────────────────────────────────────
df <- df %>%
  mutate(
    atuh_score         = rowMeans(across(starts_with("atuh")), na.rm = TRUE),
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

cat("\n--- Tech-Affinität (ATUH, 1-4) ---\n")
cat("M =", round(mean(df$atuh_score, na.rm = TRUE), 2),
    " SD =", round(sd(df$atuh_score, na.rm = TRUE), 2), "\n")

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

# Alter
ggplot(df, aes(x = alter)) +
  geom_histogram(binwidth = 2, fill = "steelblue", color = "white") +
  labs(title = "Altersverteilung", x = "Alter (Jahre)", y = "Häufigkeit") +
  theme_minimal(base_size = 14)

# Big Five Profil
df %>%
  summarise(across(
    c(extraversion, vertraeglichkeit, gewissenhaftigkeit, neurotizismus, offenheit),
    ~ mean(.x, na.rm = TRUE)
  )) %>%
  pivot_longer(everything(), names_to = "Skala", values_to = "M") %>%
  ggplot(aes(x = Skala, y = M, fill = Skala)) +
  geom_col(show.legend = FALSE) +
  geom_hline(yintercept = 3, linetype = "dashed", color = "gray50") +
  ylim(1, 5) +
  labs(title = "Big Five Profil", x = NULL, y = "Mittelwert (1-5)") +
  theme_minimal(base_size = 14)

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

