# =============================================================================
# prep/01_build_wpp_latam.R
# -----------------------------------------------------------------------------
# Construye el subconjunto de datos del World Population Prospects 2024 (ONU)
# para América Latina y el Caribe (1950-2023), listo para alimentar los modelos
# de parentesco de DemoKin (kin2sex, bisexual y variable en el tiempo).
#
# Para cada país se genera una tabla ordenada (tidy) con las columnas:
#   iso3, country, year, sex ("f"/"m"), age (0-100), px, qx, mx, fx, pop
#   - px, qx, mx : supervivencia / mortalidad por sexo (tablas de vida completas)
#   - fx         : tasa de fecundidad específica por edad (mujeres; 0 en hombres)
#   - pop        : población al 1 de enero por sexo y edad (personas)
# La fecundidad masculina se aproxima en el laboratorio con el supuesto
# androgino (fm = ff), como en los cursos de referencia.
#
# Salida:
#   data/wpp_latam_1950_2023.zip   (un parquet por país + countries.csv)
#   data/countries.csv             (lista de países incluidos)
#
# Fuente (archivos grandes, NO se incluyen en el repositorio):
#   C:/cloud2/Projects/__data/wpp2024/
#
# Ejecutar una sola vez desde la raíz del repositorio:
#   Rscript prep/01_build_wpp_latam.R
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(arrow)
})

wpp_dir <- "C:/cloud2/Projects/__data/wpp2024"
out_dir <- "data"
tmp_dir <- file.path("C:/tmp", paste0("wpp_latam_", Sys.getpid()))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)

yrs <- 1950:2023

# --- Países de América Latina y el Caribe (estados soberanos) ----------------
lac <- tribble(
  ~iso3, ~country,
  "ARG", "Argentina",           "BOL", "Bolivia",
  "BRA", "Brasil",              "CHL", "Chile",
  "COL", "Colombia",            "ECU", "Ecuador",
  "GUY", "Guyana",              "PRY", "Paraguay",
  "PER", "Perú",                "SUR", "Surinam",
  "URY", "Uruguay",             "VEN", "Venezuela",
  "BLZ", "Belice",              "CRI", "Costa Rica",
  "SLV", "El Salvador",         "GTM", "Guatemala",
  "HND", "Honduras",            "MEX", "México",
  "NIC", "Nicaragua",           "PAN", "Panamá",
  "CUB", "Cuba",                "DOM", "República Dominicana",
  "HTI", "Haití",               "JAM", "Jamaica",
  "TTO", "Trinidad y Tobago"
)
lac_iso <- lac$iso3

# --- Lector filtrado (solo columnas y filas necesarias) ----------------------
read_wpp <- function(file, cols) {
  message("Leyendo ", basename(file), " ...")
  readr::read_csv(file.path(wpp_dir, file),
    col_select = all_of(cols),
    show_col_types = FALSE, progress = FALSE
  ) %>%
    filter(
      LocTypeName == "Country/Area",
      Variant == "Medium",
      ISO3_code %in% lac_iso,
      Time %in% yrs
    )
}

# --- 1. Mortalidad / supervivencia (tablas de vida completas por sexo) -------
lt_cols <- c(
  "ISO3_code", "LocTypeName", "Variant", "Time", "AgeGrpStart",
  "px", "qx", "mx"
)

lt_f <- read_wpp("WPP2024_Life_Table_Complete_Medium_Female_1950-2023.csv.gz", lt_cols) %>%
  transmute(iso3 = ISO3_code, year = Time, age = AgeGrpStart, sex = "f", px, qx, mx)
lt_m <- read_wpp("WPP2024_Life_Table_Complete_Medium_Male_1950-2023.csv.gz", lt_cols) %>%
  transmute(iso3 = ISO3_code, year = Time, age = AgeGrpStart, sex = "m", px, qx, mx)
lt <- bind_rows(lt_f, lt_m)

# --- 2. Fecundidad (ASFR femenina, por 1000 mujeres) -------------------------
fert <- read_wpp(
  "WPP2024_Fertility_by_Age1.csv.gz",
  c("ISO3_code", "LocTypeName", "Variant", "Time", "AgeGrpStart", "ASFR")
) %>%
  transmute(iso3 = ISO3_code, year = Time, age = AgeGrpStart, fx = ASFR / 1000)

# --- 3. Población al 1 de enero por sexo (en miles -> personas) --------------
pop <- read_wpp(
  "WPP2024_Population1JanuaryBySingleAgeSex_Medium_1950-2023.csv",
  c(
    "ISO3_code", "LocTypeName", "Variant", "Time", "AgeGrpStart",
    "PopMale", "PopFemale"
  )
) %>%
  transmute(
    iso3 = ISO3_code, year = Time, age = AgeGrpStart,
    f = PopFemale * 1000, m = PopMale * 1000
  ) %>%
  pivot_longer(c(f, m), names_to = "sex", values_to = "pop")

# --- 4. Ensamblar tabla ordenada por país y guardar parquet ------------------
wpp <- lt %>%
  left_join(pop, by = c("iso3", "year", "sex", "age")) %>%
  left_join(fert %>% mutate(sex = "f"), by = c("iso3", "year", "sex", "age")) %>%
  mutate(fx = replace_na(fx, 0)) %>%
  left_join(lac, by = "iso3") %>%
  select(iso3, country, year, sex, age, px, qx, mx, fx, pop) %>%
  arrange(iso3, sex, year, age)

# --- 4b. Archivo (marcador de posición) de mortalidad por homicidio ----------
# El Módulo 4 y las Soluciones necesitan tasas de mortalidad ESPECÍFICAS POR
# HOMICIDIO por país, año, sexo y edad. Ese archivo aún no existe. Mientras tanto
# generamos un marcador de posición con la MISMA estructura y nombre que tendrá el
# archivo real (homicide_mortality_rates.csv), usando la mortalidad por TODAS las
# causas del WPP (columna mx). Cuando llegue el archivo real de homicidios, basta
# con reemplazar data/homicide_mortality_rates.csv (mismo esquema) y el código no
# cambia.
homicide_rates <- wpp %>%
  select(iso3, year, sex, age, mx) %>%
  mutate(mx = round(mx, 8))
write_csv(homicide_rates, file.path(out_dir, "homicide_mortality_rates.csv"))

built <- character(0)
for (code in lac_iso) {
  dat <- wpp %>% filter(iso3 == code)
  if (nrow(dat) == 0) {
    message("Sin datos para ", code, " (omitido)")
    next
  }
  write_parquet(dat, file.path(tmp_dir, paste0("wpp_", code, ".parquet")),
    compression = "zstd"
  )
  built <- c(built, code)
}

# lista de países efectivamente incluidos
countries <- lac %>% filter(iso3 %in% built)
write_csv(countries, file.path(tmp_dir, "countries.csv"))
write_csv(countries, file.path(out_dir, "countries.csv"))

# --- 5. Empaquetar en un único zip -------------------------------------------
zip_path <- normalizePath(file.path(out_dir, "wpp_latam_1950_2023.zip"),
  mustWork = FALSE
)
if (file.exists(zip_path)) file.remove(zip_path)
files_to_zip <- list.files(tmp_dir, full.names = TRUE)
# zip con rutas planas (junk paths) para que dentro del zip queden solo los .parquet
old <- setwd(tmp_dir)
utils::zip(
  zipfile = zip_path, files = basename(files_to_zip),
  flags = "-j9X"
)
setwd(old)

unlink(tmp_dir, recursive = TRUE)

cat("\nPaíses incluidos (", length(built), "):\n", paste(built, collapse = ", "), "\n", sep = "")
cat(
  "Zip:", zip_path, "-",
  round(file.info(zip_path)$size / 1024^2, 2), "MB\n"
)
