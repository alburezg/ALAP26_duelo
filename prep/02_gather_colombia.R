# =============================================================================
# prep/02_gather_colombia.R
# -----------------------------------------------------------------------------
# Extrae del paquete de replicación OSF del artículo de Colombia
# (Acosta et al. 2026, "Weaponizing Kinship") únicamente los archivos de
# ENTRADA que necesita el Módulo 3, y los re-guarda en formato compacto
# (parquet/csv) dentro de data/colombia/.
#
# NOTA: solo se guardan datos de ENTRADA (tasas demográficas, muertes por
# homicidio, inmigrantes, totales). La estructura de parentesco (salida del
# modelo DemoKin, ~20 MB) NO se guarda aquí: se regenera al ejecutar el
# Módulo 3 y está en el .gitignore.
#
# Fuente : C:/cloud2/Projects/kin_conflict_colombia/osf.zip
#          (carpeta raíz dentro del zip: colombia_bereavement_pdr/)
# Salida : data/colombia/  (archivos pequeños, aptos para el repositorio)
#
# Ejecutar una sola vez desde la raíz del repositorio:
#   Rscript prep/02_gather_colombia.R
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(arrow)
})

# --- Rutas -------------------------------------------------------------------
# El paquete de replicación OSF puede estar descomprimido (carpeta osf/) o como
# osf.zip. Usamos la carpeta si existe; si no, extraemos del zip.
osf_dir <- "C:/cloud2/Projects/kin_conflict_colombia/osf"
osf_zip <- "C:/cloud2/Projects/kin_conflict_colombia/osf.zip"
zip_root <- "colombia_bereavement_pdr/data_inter"
out_dir <- "data/colombia"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

entries <- c(
  "demo_data_1900_2100.rds",
  "conflict_data_by_single_age_sex_1985_2018_mean.rds",
  "estimation-totals.rds",
  "colombia_immigrants_by_age_sex_dept_census_2018.rds"
)

# --- 1. Localizar los archivos de entrada ------------------------------------
src_dir <- file.path(osf_dir, zip_root)
tmp_dir <- NULL

if (dir.exists(src_dir)) {
  message("Leyendo desde el paquete OSF descomprimido: ", src_dir)
} else {
  # Extraer del zip a un directorio temporal de ruta corta (límite MAX_PATH de Windows)
  message("Extrayendo archivos de osf.zip ...")
  tmp_dir <- file.path("C:/tmp", paste0("osf_col_", Sys.getpid()))
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  unzip_bin <- Sys.which("unzip")
  if (!nzchar(unzip_bin)) stop("No se encontró 'unzip' ni la carpeta OSF descomprimida.")
  system2(unzip_bin,
    c(
      "-o", "-j", shQuote(osf_zip),
      shQuote(file.path(zip_root, entries)),
      "-d", shQuote(tmp_dir)
    ),
    stdout = FALSE
  )
  src_dir <- tmp_dir
}

rd <- function(f) readRDS(file.path(src_dir, f))

# --- 2. Datos demográficos (insumos DemoKin + población para el duelo) -------
# Para el taller usamos SOLO 1950-2018 (datos del WPP), sin historia anterior a
# 1950 ni proyecciones posteriores a 2018, para que el modelo de parentesco corra
# rápido. Esto da resultados algo distintos a los del artículo (que usa
# 1900-2100), pero mucho más prácticos para el taller. 'ax' convierte la tasa de
# mortalidad por homicidio (mx) en probabilidad (qx).
demo <- rd("demo_data_1900_2100.rds") %>%
  filter(year %in% 1950:2018) %>%
  transmute(
    year, sex, age,
    fx, px, nx, pop, ax
  ) %>%
  arrange(sex, year, age)

write_parquet(demo, file.path(out_dir, "col_demo_1950_2018.parquet"),
  compression = "zstd"
)

# --- 3. Muertes por el conflicto: SOLO homicidios ----------------------------
# violation == "dts" = homicidios (el taller considera únicamente homicidios).
conflict <- rd("conflict_data_by_single_age_sex_1985_2018_mean.rds") %>%
  filter(violation == "dts") %>%
  transmute(year, sex, age = as.integer(age), dx) %>%
  arrange(sex, year, age)

write_parquet(conflict, file.path(out_dir, "col_homicidios_1985_2018.parquet"),
  compression = "zstd"
)

# --- 4. Totales de homicidios (denominador de los multiplicadores) -----------
# Estimación puntual (N_mean) de la estimación por sistemas múltiples (MSE).
totals <- rd("estimation-totals.rds")
homicide_totals <- totals$violation %>%
  filter(violation == "Homicide") %>%
  transmute(violation = "Homicidios", n_muertes = N_mean)

write_csv(homicide_totals, file.path(out_dir, "col_homicidios_totales.csv"))

# --- 5. Proporción de inmigrantes a nivel nacional (para la exposición) ------
# El artículo excluye a los inmigrantes del riesgo de duelo. Derivamos la
# proporción nacional imm_r = inmigrantes / población (censo 2018).
pop_2018 <- demo %>%
  filter(year == 2018) %>%
  select(sex, age, pop)

immigrants <- rd("colombia_immigrants_by_age_sex_dept_census_2018.rds") %>%
  filter(dpt == "Nacional") %>%
  transmute(sex, age = as.integer(age), imm) %>%
  left_join(pop_2018, by = c("sex", "age")) %>%
  mutate(imm_r = if_else(pop > 0, pmin(imm / pop, 1), 0)) %>%
  transmute(sex, age, imm_r) %>%
  arrange(sex, age)

write_parquet(immigrants, file.path(out_dir, "col_inmigrantes_2018.parquet"),
  compression = "zstd"
)

# --- 6. Limpieza y reporte ---------------------------------------------------
if (!is.null(tmp_dir)) unlink(tmp_dir, recursive = TRUE)

sizes <- file.info(list.files(out_dir, full.names = TRUE))["size"]
cat("\nArchivos escritos en", out_dir, ":\n")
print(round(sizes / 1024^2, 2))
cat("\nTotal:", round(sum(sizes) / 1024^2, 2), "MB\n")
