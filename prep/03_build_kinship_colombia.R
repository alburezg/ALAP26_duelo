# =============================================================================
# prep/03_build_kinship_colombia.R
# -----------------------------------------------------------------------------
# Genera la ESTRUCTURA DE PARENTESCO de Colombia (salida del modelo DemoKin)
# que usa el Módulo 3 para estimar el duelo. Es el "modelo de parentesco"
# ejecutado sobre las tasas colombianas 1900-2018 (data/colombia/col_demo_...).
#
# Corre kin2sex (bisexual, variable en el tiempo, salida por período 1985-2018)
# para Focal mujer y hombre, y guarda el número esperado de parientes vivos.
#
# ADVERTENCIA: este cálculo tarda ~15-20 minutos. El resultado se distribuye
# pre-generado en data/colombia/col_kin_1985_2018.parquet para que el
# laboratorio del Módulo 3 sea ágil; este script permite regenerarlo.
#
#   Rscript prep/03_build_kinship_colombia.R
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(arrow)
  library(DemoKin)
})

d <- "data/colombia"
demo <- read_parquet(file.path(d, "col_demo_1950_2018.parquet"))

# tidy -> matriz (edad x año)
to_mat <- function(df, value, which_sex) {
  df %>%
    filter(sex == which_sex) %>%
    select(age, year, value = all_of(value)) %>%
    arrange(age, year) %>%
    pivot_wider(names_from = year, values_from = value) %>%
    select(-age) %>%
    as.matrix()
}

pf <- to_mat(demo, "px", "f")
pm <- to_mat(demo, "px", "m")
ff <- to_mat(demo, "fx", "f")
fm <- to_mat(demo, "fx", "m")
nf <- to_mat(demo, "nx", "f")
nm <- to_mat(demo, "nx", "m")

# kin2sex corre para un sexo de Focal; lo llamamos para mujeres y hombres.
message("Corriendo kin2sex para Focal mujer...")
kin_f <- kin2sex(
  pf = pf, pm = pm, ff = ff, fm = fm, nf = nf, nm = nm,
  time_invariant = FALSE,
  output_period = 1985:2018,
  output_kin = c("c", "d", "gd", "gm", "m", "n", "a", "s"),
  sex_focal = "f"
)

message("Corriendo kin2sex para Focal hombre...")
kin_m <- kin2sex(
  pf = pf, pm = pm, ff = ff, fm = fm, nf = nf, nm = nm,
  time_invariant = FALSE,
  output_period = 1985:2018,
  output_kin = c("c", "d", "gd", "gm", "m", "n", "a", "s"),
  sex_focal = "m"
)

kin <- bind_rows(
  as_tibble(kin_f$kin_full) %>% mutate(sex_focal = "f"),
  as_tibble(kin_m$kin_full) %>% mutate(sex_focal = "m")
) %>%
  transmute(
    year = as.integer(year),
    sex_focal,
    age_focal = as.integer(age_focal),
    kin,
    sex_kin,
    age_kin = as.integer(age_kin),
    living
  ) %>%
  filter(living >= 1e-6) # descartar celdas ~0 (no cambian (1-q)^living)

# guardar compacto: enteros para edades/año, float32 para 'living'
kin_tab <- arrow::as_arrow_table(kin)$cast(arrow::schema(
  year      = arrow::int16(),
  sex_focal = arrow::utf8(),
  age_focal = arrow::int16(),
  kin       = arrow::utf8(),
  sex_kin   = arrow::utf8(),
  age_kin   = arrow::int16(),
  living    = arrow::float32()
))

write_parquet(kin_tab, file.path(d, "col_kin_1985_2018.parquet"),
  compression = "zstd"
)

cat(
  "Guardado:", file.path(d, "col_kin_1985_2018.parquet"), "-",
  round(file.info(file.path(d, "col_kin_1985_2018.parquet"))$size / 1024^2, 2),
  "MB\n"
)
