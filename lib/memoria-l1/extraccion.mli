(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La extracción de átomos: la entrada del agente [memoria-atomos] y la
    lectura de lo que responde. Puro.

    Los mensajes van etiquetados: los de fondo [f1], [f2]… (solo contexto,
    prohibido extraer de ellos) y los nuevos [m1], [m2]…; el modelo cita
    las etiquetas y aquí se traducen a [sesion/uuid]. Las etiquetas cortas
    gastan menos tokens que los uuid y el modelo no se los inventa. *)

val max_texto : int
(** Caracteres (bytes) por mensaje en la entrada; lo que pasa se recorta por
    el medio. *)

val recortar : int -> string -> string
(** Deja el principio y el final, con [ […] ] en medio, sin partir un
    carácter UTF-8. *)

val entrada : escena_previa:string option -> fondo:Atomo.mensaje list -> nuevos:Atomo.mensaje list -> string
(** El mensaje de usuario del encargo: escena anterior, 【fondo】 y 【nuevos】,
    cada mensaje con su etiqueta, su autor ({!Atomo.autor}: usuario,
    asistente, agente padre o tarea programada) y su hora UTC. *)

type resultado = {
  escenas : string list;  (** En orden de aparición. *)
  ultima_escena : string option;  (** La que hereda el siguiente lote. *)
  atomos : Atomo.nuevo list;
  descartados : (string * string) list;
      (** Átomos que el modelo dio y no valen, con el motivo: tipo
          desconocido, prioridad bajo el umbral, sin origen entre los
          nuevos (citar el fondo no vale)… *)
}

val leer : clave:string -> nuevos:Atomo.mensaje list -> string -> (resultado, string) result
(** Lee la respuesta. Los ids de los átomos salen de [clave] (la del lote,
    [sesion/hasta]) y su orden ({!Atomo.id_de}). Una [persona] o una [regla]
    tiene que citar algún mensaje del usuario de verdad ({!Atomo.autor}):
    lo que escribe un agente padre o el prompt de una tarea programada no
    es su voz. [Error] si no hay un JSON con escenas: el encargo
    salió mal. Las fechas de cada átomo son las de sus mensajes de origen
    (de su [ts], nunca del modelo); su proyecto, el del primero. *)
