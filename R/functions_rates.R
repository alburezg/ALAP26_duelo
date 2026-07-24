# ----------------------------------------------------------------------------
# Funciones para escribir los archivos de tasas de entrada de SOCSIM
# (fecundidad y mortalidad) a partir de los datos del WPP 2024.
#
# Adaptado del taller ALAP 2024 para leer los archivos .parquet del WPP que
# preparamos para este taller (data/wpp_latam_1950_2023/wpp_<ISO3>.parquet), en lugar de
# los .RData originales.
# ----------------------------------------------------------------------------

options(scipen = 999999)

# Lee los datos del WPP para un país (ISO3) desde el .parquet preparado.
.leer_wpp_pais <- function(iso) {
  arrow::read_parquet(file.path("data/wpp_latam_1950_2023", paste0("wpp_", iso, ".parquet")))
}

# ----------------------------------------------------------------------------
#### Tasas de fecundidad para SOCSIM ----

write_socsim_fertility_rates_WPP <- function(country = "Colombia", iso = "COL", rates_dir = "rates") {
  dir.create(rates_dir, recursive = TRUE, showWarnings = FALSE)

  # Fecundidad femenina por edad simple [15-49] (tasas por mujer, anuales)
  data <- .leer_wpp_pais(iso) %>%
    filter(sex == "f", age >= 15, age <= 49) %>%
    select(year, age, fx)

  # Convertir a tasas mensuales y usar el límite superior de edad que usa SOCSIM
  ASFR <-
    data %>%
    mutate(
      Age_up = age + 1,
      Month = 0,
      fx_mo = fx / 12
    ) %>%
    select(-fx)

  # Añadir filas con tasa 0 para las edades 0-15 y 50-101
  ASFR <-
    ASFR %>%
    group_by(year) %>%
    group_split() %>%
    map_df(~ add_row(.x,
      year = unique(.x$year),
      age = 0, Age_up = 15, Month = 0, fx_mo = 0.0, .before = 1
    )) %>%
    group_by(year) %>%
    group_split() %>%
    map_df(~ add_row(.x,
      year = unique(.x$year),
      age = 50, Age_up = 101, Month = 0, fx_mo = 0.0, .after = 36
    )) %>%
    ungroup() %>%
    select(-age)

  years <- ASFR %>%
    pull(year) %>%
    unique()
  rows_ageF <- ASFR %>%
    pull(Age_up) %>%
    unique() %>%
    seq_along()

  for (year in years) {
    n <- which(year == years)
    n_row <- (n - 1) * 37 + rows_ageF

    outfilename <- file(file.path(rates_dir, paste0(country, "fert", year)), "w")
    cat(c("** Period (Monthly) Age-Specific Fertility Rates for", country, "in", year, "\n"),
      file = outfilename
    )
    cat(c("* Retrieved from the World Population Prospects 2024", "\n"), file = outfilename)
    cat("\n", file = outfilename)

    cat("birth", "1", "F", "single", "0", "\n", file = outfilename)
    for (i in n_row) cat(c(as.matrix(ASFR)[i, -1], "\n"), file = outfilename)
    cat("\n", file = outfilename)

    cat("birth", "1", "F", "married", "0", "\n", file = outfilename)
    for (i in n_row) cat(c(as.matrix(ASFR)[i, -1], "\n"), file = outfilename)

    close(outfilename)
  }
}

# ----------------------------------------------------------------------------
#### Probabilidades de muerte para SOCSIM ----

write_socsim_mortality_rates_WPP <- function(country = "Colombia", iso = "COL", rates_dir = "rates") {
  dir.create(rates_dir, recursive = TRUE, showWarnings = FALSE)

  # Probabilidades de muerte (qx) por edad simple [0-100] y sexo
  data <- .leer_wpp_pais(iso) %>%
    transmute(year,
      Sex = factor(if_else(sex == "f", "Female", "Male"),
        levels = c("Female", "Male")
      ),
      age, qx
    )

  # Convertir probabilidades anuales en mensuales (Wachter 2014, p. 53)
  ASMP <-
    data %>%
    mutate(
      qx_mo = if_else(age == 100, qx / 12, 1 - (1 - qx)^(1 / 12)),
      Age_up = age + 1,
      Month = 0
    ) %>%
    select(year, Age_up, Month, Sex, qx_mo) %>%
    pivot_wider(names_from = Sex, values_from = qx_mo) # columnas: Female, Male

  years <- ASMP %>%
    pull(year) %>%
    unique()
  rows_ageM <- ASMP %>%
    pull(Age_up) %>%
    unique() %>%
    seq_along()

  for (year in years) {
    n <- which(year == years)
    n_row <- (n - 1) * 101 + rows_ageM

    outfilename <- file(file.path(rates_dir, paste0(country, "mort", year)), "w")
    cat(c("** Period (Monthly) Age-Specific Probabilities of Death for", country, "in", year, "\n"),
      file = outfilename
    )
    cat(c("* Retrieved from the World Population Prospects 2024. Single age life tables", "\n"),
      file = outfilename
    )
    cat(c("** The final age interval is limited to one year [100-101)", "\n"), file = outfilename)
    cat("\n", file = outfilename)

    # Mujeres solteras (columnas year, Age_up, Month, Female, Male -> quitar year y Male)
    cat("death", "1", "F", "single", "\n", file = outfilename)
    for (i in n_row) cat(c(as.matrix(ASMP)[i, -c(1, 5)], "\n"), file = outfilename)
    cat("\n", file = outfilename)

    # Hombres solteros (quitar year y Female)
    cat("death", "1", "M", "single", "\n", file = outfilename)
    for (i in n_row) cat(c(as.matrix(ASMP)[i, -c(1, 4)], "\n"), file = outfilename)

    close(outfilename)
  }
}
