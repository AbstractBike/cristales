(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La ficha de empresa para un headhunter (herramienta [company_profile]),
    campo a campo.

    Un cristal {e parcial} y conservador: de los 13 campos de la ficha da
    solo los que la propia evidencia sostiene, y en cada ficha los que pueda.
    No sabe nada del mundo: la sede, el tamaño o la web de una empresa que la
    evidencia no dice se los pide la forja al LLM, igual que el resumen, el
    sector, la ciudad, las señales de alarma, las tecnologías y la confianza.

    - [remotePolicy]: [remote] si todas las ubicaciones vistas son remotas y
      nada habla de oficina; [onsite] si todas son presenciales.
    - [website]: un dominio que aparece en la evidencia (no en un correo) y
      que es el nombre de la empresa.
    - [hqCountry] y [hqCountryEn]: la sede dicha en primera persona («our
      Berlin HQ», «headquartered in Amsterdam, we…»), por una tabla de
      ciudades y países.
    - [sizeBucket]: una plantilla dicha («1200+ colleagues», «56.000
      empleados», «we're ~20 people»). *)

type evidencia = {
  empresa : string;
  ubicaciones : string list;  (** Separadas por «·» o «;» en la línea. *)
  ofertas : string list;  (** Los títulos de sus ofertas. *)
  extracto : string;  (** Hasta [</evidence>]. *)
}

val leer : string -> evidencia option
(** El bloque [<evidence>] con [Empresa:], [Ubicaciones vistas:], [Ofertas
    suyas vistas:] (líneas [- …]) y [Extracto de una de sus ofertas:]. Sin
    [<evidence>] o sin empresa, [None]. *)

val campos : evidencia -> (string * Yojson.Safe.t) list
(** Los campos que la evidencia sostiene, con los nombres de la ficha. *)

val cristal : (string, string) Cristal.cristal
(** El mensaje → el objeto JSON con esos campos. Defecto si no hay
    evidencia o si no sostiene ninguno. *)
