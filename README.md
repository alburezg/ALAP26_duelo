# Escuela ALAP 2026 — Demografía del parentesco con énfasis en estimaciones de duelo

Materiales del taller de la Escuela de la Asociación Latinoamericana de Población
(ALAP), San José, Costa Rica, 24–25 de agosto de 2026.

- **Repositorio:** <https://github.com/alburezg/ALAP26_duelo>
- **Sitio web del curso:** <https://alburezg.github.io/ALAP26_duelo/>

**Docentes:** Diego Alburez-Gutierrez, Enrique Acosta, Liliana Calderón
(Instituto Max Planck de Investigación Demográfica; Centro de Estudios
Demográficos, Barcelona).

El sitio web del curso se genera a partir de `index.Rmd`, que reúne un módulo por
pestaña (`modulo_1.Rmd` … `modulo_6.Rmd`) mediante documentos hijos (*child
documents*). Para compilarlo:

```r
rmarkdown::render("index.Rmd")
```

## Estructura

| Archivo | Contenido |
|---|---|
| `index.Rmd` | Documento maestro (pestañas por módulo) |
| `modulo_1.Rmd` | Introducción a la demografía del parentesco + laboratorio de preparación técnica |
| `modulo_2.Rmd` | Laboratorio: estimación de parentesco con DemoKin (modelo de dos sexos variable en el tiempo, enfoque por período) |
| `modulo_3.Rmd` | Demografía del duelo + laboratorio: conflicto colombiano (cuatro medidas clave) |
| `modulo_4.Rmd` | Laboratorio de ejercicios: replicar el análisis para otro país |
| `modulo_5.Rmd`, `modulo_6.Rmd` | Microsimulación con SOCSIM (`rsocsim`): correr una simulación y estimar la pérdida de parientes |
| `soluciones.Rmd` | Solución completa del ejercicio del Módulo 4, resuelta para Costa Rica |
| `data/` | Datos de entrada del taller (véase la pestaña **Datos** del sitio) |

## Datos

- `data/wpp_latam_1950_2023.zip` — insumos del World Population Prospects 2024
  (mortalidad, fecundidad, población) para ~25 países de América Latina y el
  Caribe, 1950–2023. Un archivo `.parquet` por país.
- `data/countries.csv` — lista de países incluidos.
- `data/homicide_mortality_rates.csv` — tasas de mortalidad por homicidio por país
  (Módulo 4). **Marcador de posición** (por ahora, mortalidad por todas las
  causas); se reemplazará por el archivo real conservando el mismo esquema.
- `data/colombia/` — datos de entrada del artículo del conflicto colombiano
  (Acosta et al. 2026): tasas demográficas (`col_demo_1950_2018.parquet`),
  muertes por homicidio (`col_homicidios_1985_2018.parquet`), inmigrantes y
  totales de homicidios. La estructura de parentesco (`col_kin_1985_2018.parquet`)
  **no se versiona**: es una salida del modelo que el Módulo 3 genera a partir de
  esas tasas la primera vez que se ejecuta y luego reutiliza (caché).

La documentación completa de cada insumo (contenido, columnas, fuente y
referencia) está en la pestaña **Datos** del sitio.

Solo se versionan los archivos de **entrada** y el **código**; todo lo que se
genera al correr los laboratorios (estructuras de parentesco, resultados de
SOCSIM, sitio HTML, cachés) está en el `.gitignore`. Los scripts de preparación
de datos (`prep/`), que construyen los insumos a partir de fuentes originales no
versionadas por su tamaño, son de uso interno de los docentes y no se distribuyen.

## Requisitos

R (≥ 4.2), RStudio y los paquetes `tidyverse`, `arrow`,
[`DemoKin`](https://github.com/IvanWilli/DemoKin) y
[`rsocsim`](https://cran.r-project.org/package=rsocsim). La instalación se cubre
en el Módulo 1.

## Referencias

Acosta, E., Alburez-Gutierrez, D., Gargiulo, M., & Torres, C. (2026).
*Weaponizing Kinship: A Demographic Analysis of Bereavement in the Colombian
Conflict.* Population and Development Review. doi:10.1111/padr.70048
