(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Los cristales que atienden el proxy (forja) y el servidor MCP
   (forja-mcp). Añadir uno es un commit: se nuclea desde el horno, se revisa,
   se mete en cristales/<tarea>/ y se registra aquí, con una descripción
   para quien lo llame como herramienta. Los cristales tipados se
   adaptan a texto → texto; el contexto que necesiten (la fecha de hoy) lo
   pone el adaptador, no el cristal. *)

let tarea n = Result.get_ok (Forja.Tarea.explicita n)

let hoy () =
  let t = Unix.gmtime (Unix.time ()) in
  { Fecha_es.anyo = t.tm_year + 1900; mes = t.tm_mon + 1; dia = t.tm_mday }

let fecha_es =
  Cristal.cristal "fecha-es" (fun texto ->
      Result.map Fecha_es.iso (Fecha_es.aplicar ~hoy:(hoy ()) (String.trim texto)))

let vitrina =
  Forja.Vitrina.(
    vacia
    |> con (tarea "fecha-es") `Mixta fecha_es
         ~descripcion:
           "Convierte una fecha escrita en español (\"3 de marzo de 2024\", \"03/03/24\", \"15 de \
            agosto\", \"mañana\") a ISO 8601 (AAAA-MM-DD), relativa a hoy. Lee las fechas \
            numéricas como día/mes/año. Da un defecto con fechas imposibles, rangos o \
            expresiones relativas como \"el próximo martes\"."
    (* graficas.email (2026-10-12): las llama como herramientas en cada anuncio y cada titular. *)
    |> con (tarea "grafica-modelo") `Mixta Grafica_modelo.cristal
         ~descripcion:
           "Las gráficas de sobremesa que nombra un texto (\"MSI RTX 3080 Ti 12GB\", \"una 6800 XT\", \"Arc \
            A770\"), con su clave, fabricante, memoria, año, precio de lanzamiento y un índice \
            orientativo de rendimiento (RTX 4090 = 100). No confunde procesadores (5800X3D, i5 10400F), \
            resoluciones (1080p) ni fuentes (650W). Defecto si no nombra ninguna o solo desconocidas."
    |> con (tarea "grafica-anuncio") `Mixta Grafica_anuncio.cristal
         ~descripcion:
           "Qué se vende en un anuncio de segunda mano de informática (líneas Título:, Categoría:, \
            Descripción:; o solo el título): una gráfica suelta y cuál, o un PC, un portátil, una pieza, \
            un componente, un lote o alguien que busca; y su estado (nueva, usada, averiada), minería, \
            garantía, factura, caja y cambio. Defecto si no sabe qué gráfica es."
    |> con (tarea "grafica-noticia") `Mixta Grafica_noticia.cristal
         ~descripcion:
           "De qué va una noticia de hardware (Título:, Resumen:; o solo el titular) para quien sigue \
            las gráficas de sobremesa: si va de ellas, su tipo (drivers, análisis, rumor, precio, \
            mercado, lanzamiento, anuncio), fabricantes, modelos y las gráficas que aún no estaban en \
            el catálogo."
    (* nvme.email (2026-10-12): como graficas.email, en cada anuncio de discos y cada titular. *)
    |> con (tarea "nvme-modelo") `Mixta Nvme_modelo.cristal
         ~descripcion:
           "Los SSD que nombra un texto (\"WD_BLACK SN850X 2TB\", \"Samsung PM9A3 7,68TB U.2\", \"una 990 Pro\"), \
            con su clave, marca, segmento (consumo o enterprise), interfaz (PCIe 3/4/5, SATA, SAS), \
            formato (M.2 2280/22110, U.2, U.3), DRAM o HMB, NAND (TLC, QLC…), PLP, la capacidad que dice \
            y su TBW. No confunde velocidades (7300 MB/s), memoria de PC (16GB RAM) ni resistencia \
            (600TBW). Defecto si no nombra ninguno del catálogo o solo desconocidos."
    |> con (tarea "nvme-anuncio") `Mixta Nvme_anuncio.cristal
         ~descripcion:
           "Qué se vende en un anuncio de segunda mano de discos (líneas Título:, Categoría:, \
            Descripción:; o solo el título): un SSD NVMe suelto y cuál, o un SATA, un disco duro, un \
            externo, una caja sin disco, un adaptador, un PC, un portátil, una consola, un componente, \
            un lote o alguien que busca; su estado, su salud (horas, TB escritos, % de vida, SMART) y \
            lo que dice de garantía, factura, caja y cambio. Defecto si no sabe qué disco es."
    |> con (tarea "nvme-noticia") `Mixta Nvme_noticia.cristal
         ~descripcion:
           "De qué va una noticia de hardware (Título:, Resumen:; o solo el titular) para quien sigue \
            los SSD: si va de SSD y flash, de almacenamiento (discos duros, NAS, cabinas) o de otra \
            cosa; su tipo (análisis, rumor, precio, mercado, lanzamiento, anuncio, firmware), su \
            segmento, fabricantes, modelos y los SSD que aún no estaban en el catálogo."
    (* memorias.email (2026-10-13): como nvme.email, en cada anuncio de memoria y cada titular. *)
    |> con (tarea "memoria-modelo") `Mixta Memoria_modelo.cristal
         ~descripcion:
           "La memoria RAM que nombra un texto: los part numbers (\"M393A8G40AB2-CWE\", \"HMAA8GR7AJR4N-XN\", \
            \"CT32G4DFD832A\", \"KSM32RD4/64HAR\", \"CMK32GX4M2E3200C16\", etiquetas de HPE…), leídos con las reglas de \
            cada fabricante: generación, formato (UDIMM, SO-DIMM, RDIMM, LRDIMM, 3DS, ECC UDIMM, CUDIMM…), ECC, registro, \
            capacidad, velocidad, CAS, rangos y anchura; lo que el texto dice de la memoria (\"8 RDIMM de 64GB DDR4-3200 \
            2Rx4\", \"2x32GB\", \"PC4-2933Y\"); y las placas y servidores que nombra (ROME2D16-2T, H12SSL, R740, AM4…) con la \
            memoria que admiten. Defecto si no nombra nada de la memoria."
    |> con (tarea "memoria-anuncio") `Mixta Memoria_anuncio.cristal
         ~descripcion:
           "Qué se vende en un anuncio de segunda mano de memoria RAM (líneas Título:, Categoría:, Precio:, \
            Descripción:; o solo el título): un módulo, un kit o un lote (cuántos y de cuánto: \"2x32GB\" son dos de 32), \
            o un PC, un portátil, un servidor, una placa o una CPU que la llevan, otra pieza o alguien que busca; de la \
            memoria, generación, formato, ECC, registro, velocidad, CAS, rangos, voltaje, fabricante y part number; y \
            su estado, procedencia, si está probada (memtest), garantía, factura, envío, si se vende por separado, \
            unidades disponibles y precio por módulo. Defecto si no sabe cuánta memoria es."
    |> con (tarea "memoria-noticia") `Mixta Memoria_noticia.cristal
         ~descripcion:
           "De qué va una noticia de hardware (Título:, Resumen:; o solo el titular) para quien sigue la memoria \
            RAM: si va de memoria (DRAM, módulos, HBM), de almacenamiento, de otro hardware o de otra cosa; su tipo \
            (precio, mercado, fábrica, lanzamiento, análisis, estándar JEDEC), su segmento (consumo, servidor, móvil, \
            HBM/IA), fabricantes, generaciones, formatos, productos y lo que aún no se vende (DDR6, LPDDR6, HBM5…)."
    (* La extracción de trabajo.email (2026-10-12; v2 2026-10-13), la tarea de su
       prompt: un cristal parcial, da los campos que sabe y la forja le pide al
       LLM el resto. t-cab6e50313a9 es la misma extracción con otra plantilla
       (el mismo mensaje con <posting> y la misma herramienta extract_job, por
       la Messages API): el mismo cristal la sirve. *)
    |> con (tarea "t-a9fd1c2e9324") `Mixta Oferta_trabajo.cristal ~descripcion:Oferta_trabajo.descripcion
    |> con (tarea "t-cab6e50313a9") `Mixta Oferta_trabajo.cristal ~descripcion:Oferta_trabajo.descripcion
    (* La ficha de empresa para un headhunter (2026-10-13), la tarea de su
       prompt (company_profile): un cristal parcial, da solo lo que la evidencia
       sostiene y la forja le pide al LLM el resto. *)
    |> con (tarea "t-3df20b85d1d5") `Mixta Ficha_empresa.cristal
         ~descripcion:
           "De la evidencia de una empresa (<evidence> con Empresa:, Ubicaciones vistas:, sus ofertas y \
            un extracto), los campos de su ficha que el texto sostiene: remotePolicy remote si todas las \
            ubicaciones son remotas y nada habla de oficina, onsite si todas son presenciales; website si \
            un dominio de la evidencia es el nombre de la empresa; hqCountry y hqCountryEn si la sede se \
            dice en primera persona; sizeBucket si dice cuántos son. Un objeto parcial: no sabe nada del \
            mundo, y el resumen, el sector, la ciudad, las señales de alarma y la confianza no los da.")
