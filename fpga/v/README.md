# Módulos del acelerómetro (demo `DE10_LITE_GSensor` de Terasic)

Estos archivos vienen del demo de Terasic para la DE10-Lite y los referencia `comunicacion.qsf`. Con ellos el proyecto tiene todos los archivos que el `.qsf` espera.

| Archivo | Para qué sirve |
|---|---|
| `spi_ee_config.v` | Configura el ADXL345 al arrancar y lee el eje X |
| `spi_controller.v` | Controlador SPI de 3 hilos |
| `spi_param.h` | Direcciones de registros y parámetros SPI |
| `led_driver.v` | Convierte la lectura en un patrón de `LEDR` |
| `reset_delay.v` | Reset retardado (activo en bajo, ≈ 21 ms) |
| `spi_pll.qip`, `spi_pll.v`, `spi_pll_bb.v`, `spi_pll.ppf` | PLL (ALTPLL, Quartus 18.1): dos relojes de 2 MHz |

Cómo funciona todo junto: [../../docs/acelerometro.md](../../docs/acelerometro.md).

**Licencias.** Los archivos `spi_pll*` llevan el encabezado de Intel (2018) y se rigen por la licencia de Intel FPGA IP. Los demás no traen encabezado: son del demo de Terasic, así que revisa sus términos antes de publicar el repo. Si prefieres no redistribuirlos, quítalos y documenta que se obtienen del System CD o del sitio de soporte de la DE10-Lite.
