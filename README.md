# Tractor FPGA + Unity

Videojuego en **Unity** controlado con una **FPGA Terasic DE10-Lite** (Intel MAX 10) por **UART**. Un tractor recoge piezas de mantenimiento, monedas y cosechas para sumar puntos. La FPGA lee los switches, los botones y el acelerómetro de la placa, y manda un byte ASCII a Unity cada vez que algo cambia. Unity responde con un byte cuyo nibble bajo se muestra en el display de 7 segmentos.

> Proyecto académico del Tecnológico de Monterrey (curso **TE2002B, Diseño con lógica programable**), planteado como un reto inspirado en la agricultura de precisión (John Deere).

## Contenido

- [Qué hace](#qué-hace)
- [Arquitectura](#arquitectura)
- [Hardware necesario](#hardware-necesario)
- [Conexiones](#conexiones)
- [Protocolo UART](#protocolo-uart)
- [Cómo compilar y programar](#cómo-compilar-y-programar)
- [Cómo se juega](#cómo-se-juega)
- [Estructura del repo](#estructura-del-repo)
- [Estado conocido y limitaciones](#estado-conocido-y-limitaciones)
- [Trabajo futuro](#trabajo-futuro)
- [Créditos y licencias](#créditos-y-licencias)

## Qué hace

| Entrada / salida de la FPGA | Qué ocurre |
|---|---|
| Botones `KEY0` y `KEY1` | Al presionar, se manda `a` o `k` a Unity. |
| Switches `SW0` y `SW1` | Cada cambio manda una letra de "marcha": `P`, `N`, `R` o `D`. |
| Acelerómetro (inclinación) | Al cruzar un umbral se manda `l`, `r` o `X` (centro). |
| Byte recibido de Unity | Su nibble bajo (4 bits) aparece en hexadecimal en `HEX0`. |
| `LEDR[9:0]` | Muestran la lectura del acelerómetro (driver de Terasic). |

El firmware **solo notifica cambios** (eventos). No manda un flujo continuo, así que Unity debe recordar el último estado de cada fuente. Detalles en [docs/protocolo-uart.md](docs/protocolo-uart.md).

## Arquitectura

```
                 ┌──────────────────────── FPGA (MAX 10, DE10-Lite) ───────────────────────┐
 Acelerómetro ──►│ spi_ee_config ─► led_driver ─► LEDR_2 ─┐                                │
 (ADXL345, SPI)  │   (Terasic, Verilog)                   ▼                                │
 KEY0/KEY1 ─────►│ detector de flanco (bt_uart) ─┐   proceso TX con prioridad ──► uart ──► tx ──► FTDI ──► Unity
 SW0/SW1 ────────►│ detector de cambio (sw_uart) ─┼──►  bt0 > bt1 > sw > ac     (Digi-Key)       │
 LEDR_2 ─────────►│ detector de zona  (ac_uart) ──┘                                │
                 │                                                                 │
 Unity ─► FTDI ─►rx ─► uart ─► rx_data ─► (flanco de bajada de rx_busy) ─► bcd7seg_sec ─► HEX0
                 └─────────────────────────────────────────────────────────────────┘
```

| Archivo | Entidad | Función |
|---|---|---|
| `fpga/de10_lite.vhd` | `de10_lite` | Top level. Detecta eventos, arbitra qué byte mandar e instancia todo lo demás. |
| `fpga/uart.vhd` | `uart` | UART 8N1 a 115200 baudios (código de Scott Larson, Digi-Key). |
| `fpga/bcd7seg_sec.vhd` | `bcd7seg_sec` | Decodificador a 7 segmentos (activo en bajo, 0–F). |
| `fpga/clksec.vhd` | `clksec` | Divisor de reloj (~10 Hz). **No está instanciado.** |
| `fpga/v/*` | `reset_delay`, `spi_pll`, `spi_ee_config`, `led_driver` | Código de Terasic para el acelerómetro. **No incluido, ver abajo.** |

Más detalle en [docs/arquitectura.md](docs/arquitectura.md).

## Hardware necesario

- Placa **Terasic DE10-Lite** (MAX 10 `10M50DAF484`).
- Un convertidor **USB‑UART de 3.3 V** (módulo **FTDI**) y un cable USB.
- Cable USB‑Blaster (integrado en la DE10-Lite) para programar.
- PC con **Quartus Prime Lite 18.1** (la versión con la que se guardó el proyecto) y **Unity**.

## Conexiones

El FTDI se conecta a los pines GPIO de la placa. Niveles de **3.3 V**, no 5 V.

| FTDI | FPGA (DE10-Lite) | Pin del FPGA |
|---|---|---|
| RX | `tx` de la FPGA | `PIN_Y7` |
| TX | `rx` de la FPGA | `PIN_AA8` |
| 3.3V | 3.3V (header) | — |
| GND | GND (header) | — |

El reporte original indica **FTDI RX ↔ GPIO25**. Si el mapa de la placa coincide, `PIN_Y7` es GPIO25, pero **compruébalo en el manual de la DE10-Lite** antes de energizar. Asignación completa de pines en [docs/hardware.md](docs/hardware.md).

## Protocolo UART

**115200 baudios, 8 datos, sin paridad, 1 stop (8N1).**

### FPGA → Unity

| Fuente | Evento | Byte | ASCII |
|---|---|---|---|
| `KEY0` | Se presiona | `0x61` | `a` |
| `KEY1` | Se presiona | `0x6B` | `k` |
| `SW[1:0]` = `10` | Cambia el switch | `0x50` | `P` |
| `SW[1:0]` = `11` | Cambia el switch | `0x4E` | `N` |
| `SW[1:0]` = `01` | Cambia el switch | `0x52` | `R` |
| `SW[1:0]` = `00` | Cambia el switch | `0x44` | `D` |
| Acelerómetro, `LEDR` < 8 | Cambia de zona | `0x72` | `r` |
| Acelerómetro, `LEDR` > 128 | Cambia de zona | `0x6C` | `l` |
| Acelerómetro, zona central | Cambia de zona | `0x58` | `X` |

Prioridad si coinciden varios eventos en el mismo ciclo: `KEY0 > KEY1 > switches > acelerómetro`.

### Unity → FPGA

Cualquier byte. Se muestra su **nibble bajo** en `HEX0`. Si Unity manda caracteres ASCII `'0'`–`'9'` (`0x30`–`0x39`), el display mostrará ese dígito.

Especificación completa, ejemplo de lectura en C# y casos límite: [docs/protocolo-uart.md](docs/protocolo-uart.md).

## Cómo compilar y programar

1. **Consigue los archivos de Terasic** que no están en este repo y colócalos en `fpga/v/` (lista exacta en [fpga/v/README.md](fpga/v/README.md)).
2. Abre `fpga/comunicacion.qpf` en Quartus Prime Lite 18.1.
3. Verifica que el *Top-level entity* sea `de10_lite`.
4. **Processing → Start Compilation**.
5. **Tools → Programmer**, selecciona `USB-Blaster` y carga `output_files/comunicacion.sof`.
6. Si el acelerómetro no responde, prueba a mover **SW8**: el puerto `KEY[0]` del `.qsf` (`PIN_B14`) parece ser ese switch y alimenta el reset del módulo del acelerómetro (por verificar). Ver [docs/hardware.md](docs/hardware.md).
7. Conecta el FTDI, abre el puerto COM a 115200 8N1 (por ejemplo con un terminal serie) y mueve los switches: deberías ver `P`, `N`, `R`, `D`.

## Cómo se juega

1. **Avanzar o retroceder:** el estado de los switches define la marcha enviada a Unity (`P`, `N`, `R`, `D`). Qué hace Unity con cada marcha depende de su script, que no está en este repo.
2. **Izquierda o derecha:** inclina la placa. Cruzar los umbrales manda `l` o `r`; regresar al centro manda `X`.
3. **Botones:** mandan `a` y `k`. Su función exacta depende del script de Unity, que no está en este repo.
4. **Puntos:** el tractor suma al tocar monedas, cosechas y piezas. Unity manda un byte a la FPGA y el nibble bajo se ve en `HEX0`.

> El reporte original describe otra asignación (`SW0` = adelante, `SW1` = atrás, `KEY0` = habilitar giro). Ver [docs/reporte-vs-codigo.md](docs/reporte-vs-codigo.md).

## Estructura del repo

```
tractor-fpga-unity/
├── README.md
├── .gitignore
├── docs/
│   ├── arquitectura.md
│   ├── hardware.md
│   ├── protocolo-uart.md
│   ├── reporte-vs-codigo.md
│   ├── problemas-conocidos.md
│   └── Reporte_Evidencia1_Equipo_original.pdf
├── fpga/
│   ├── comunicacion.qpf / comunicacion.qsf     proyecto Quartus (sin modificar)
│   ├── DE10_LITE_GSensor.sdc                   restricciones de tiempo (heredadas de Terasic)
│   ├── de10_lite.vhd  uart.vhd  bcd7seg_sec.vhd  clksec.vhd
│   └── v/                                      código Verilog de Terasic (NO incluido)
└── unity/                                      pendiente: proyecto de Unity
```

El layout de `fpga/` es plano a propósito: el `.qsf` referencia los archivos por ruta relativa y así compila igual que el original.

## Estado conocido y limitaciones

- **El proyecto no compila solo.** Faltan los `.v` de Terasic en `fpga/v/`.
- **No se incluye el proyecto de Unity.** Solo se documenta el protocolo.
- No hay debounce ni sincronizadores en `botones`, `switches` y `rx`.
- El proceso TX tiene la lista de sensibilidad incompleta, lo que da diferencias entre simulación y hardware.
- El `.sdc` hace referencia a puertos que no existen en este diseño (`MAX10_CLK1_50`, etc.).

Lista completa con causa y arreglo propuesto: [docs/problemas-conocidos.md](docs/problemas-conocidos.md).

## Trabajo futuro

- Optimizar la comunicación entre la interfaz y el acelerómetro: mayor eficiencia de transmisión y mejor retroalimentación al usuario.
- Agricultura inteligente: incorporar principios agronómicos a los sensores para apoyar decisiones en tiempo real.
- Endurecer el firmware: sincronizadores, debounce y una cola de bytes para no perder eventos.

## Créditos y licencias

- **Reporte de referencia:** *Evidencia 1: Diseño del CPU* (29/sep/2023), Arah Rojas Blanco, Santiago López Meléndez, Jessely Jimena Santiago Bahena y Jeffry Emanuel Granados Johnson. Profesores: Enrique González Guerrero y Raúl Peña Ortega. Incluido en `docs/` como referencia.
- **Código FPGA:** basado en el repositorio `rovestrada/retoTC2002`, de otro equipo del mismo reto. **TODO:** confirmar autoría y obtener permiso o licencia antes de publicar.
- **`uart.vhd`:** Scott Larson, Digi-Key (v1.1, 2021), con modificaciones locales. Ver [docs/arquitectura.md](docs/arquitectura.md).
- **Código Verilog del acelerómetro:** Terasic (demo `DE10_LITE_GSensor`). Revisa sus términos antes de redistribuirlo.
- **Archivos de proyecto Quartus:** © Intel Corporation, sujetos a su licencia.

**TODO:** elegir una licencia para el código propio. Sin una, nadie tiene permiso explícito de reutilizarlo.
