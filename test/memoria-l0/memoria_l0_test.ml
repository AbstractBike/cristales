(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red de la ingesta L0: una prueba por patrón de redacción (y lo que no
   debe tocar), la limpieza de los transcripts, el SQL y el cursor. Los
   secretos son falsos y se arman por partes para que ningún escáner los
   tome por buenos. *)

open Memoria_l0

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let contiene s sub =
  let n = String.length sub in
  let rec ir i = i + n <= String.length s && (String.sub s i n = sub || ir (i + 1)) in
  ir 0

(* El secreto desaparece, queda la marca de su tipo y lo de alrededor. *)
let redacta nombre ?(queda = []) tipo texto secreto =
  let r, cuentas = Redaccion.redactar texto in
  comprueba (nombre ^ ": sin el secreto") (not (contiene r secreto));
  comprueba (nombre ^ ": marca") (contiene r ("[redactado:" ^ Redaccion.nombre tipo ^ "]"));
  comprueba (nombre ^ ": cuenta") (List.assoc_opt tipo cuentas = Some 1);
  List.iter (fun q -> comprueba (nombre ^ ": conserva " ^ q) (contiene r q)) queda

let intacto nombre texto =
  let r, cuentas = Redaccion.redactar texto in
  comprueba (nombre ^ ": intacto") (r = texto && cuentas = [])

let alnum = "Qx7bR2mK9pL4vN8cT1wZ5yH3jF6dS0gA"

let () =
  let pem =
    String.concat "\n"
      [ "-----BEGIN OPENSSH PRIVATE " ^ "KEY-----"; "b3BlbnNzaC1rZXktdjEAAAAABG5vbmU"; "-----END OPENSSH PRIVATE KEY-----" ]
  in
  redacta "pem" ~queda:[ "antes"; "después" ] Pem ("antes\n" ^ pem ^ "\ndespués") "b3BlbnNzaC1rZXktdjEAAAAABG5vbmU";
  redacta "pem sin END" Pem ("clave:\n-----BEGIN RSA PRIVATE " ^ "KEY-----\nMIIEpAIBAAKCAQEA0") "MIIEpAIBAAKCAQEA0";
  let ant = "sk-" ^ "ant-api03-" ^ alnum in
  redacta "anthropic" ~queda:[ "export X=" ] Anthropic ("export X=" ^ ant) ant;
  let oai = "sk-" ^ "proj-" ^ alnum in
  redacta "openai" Openai ("clave " ^ oai ^ " ok") oai;
  let gh = "gh" ^ "p_" ^ "aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3z" in
  redacta "github ghp" Github ("token " ^ gh) gh;
  let pat = "github_" ^ "pat_" ^ "11ABCDEFG0" ^ alnum in
  redacta "github_pat" Github ("usa " ^ pat) pat;
  let gl = "gl" ^ "pat-" ^ "xYz12345abcdeFGHIJ678" in
  redacta "gitlab" Gitlab ("gitlab: " ^ gl) gl;
  let sl = "xo" ^ "xb-" ^ "1234567890-abcdefghij" in
  redacta "slack" Slack ("bot " ^ sl) sl;
  let aws = "AK" ^ "IA" ^ "IOSFODNN7EXAMPLE" in
  redacta "aws" Aws ("id " ^ aws ^ ".") aws;
  let jwt = "ey" ^ "JhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U" in
  redacta "jwt" Jwt ("cookie=" ^ jwt) "dozjgNryP4J3jVmNHl0w5N";
  redacta "bearer" ~queda:[ "Authorization: Bearer " ] Bearer
    "curl -H 'Authorization: Bearer abc123def456ghi789' x" "abc123def456ghi789";
  redacta "url con credenciales" ~queda:[ "https://"; "@git.pin/repo" ] Url
    "git clone https://silvio:hunter2xyz@git.pin/repo" "hunter2xyz";
  redacta "asignación _TOKEN" ~queda:[ "INFISICAL_TOKEN=" ] Clave "INFISICAL_TOKEN=st.abc.def.12345678" "st.abc.def";
  redacta "asignación _KEY" ~queda:[ "GREPTIME_API_KEY=" ] Clave "GREPTIME_API_KEY=abcdefgh1234" "abcdefgh1234";
  redacta "asignación SECRET" ~queda:[ "client_secret" ] Clave {|{"client_secret": "GOCSPX-abcdefghijk"}|} "GOCSPX";
  redacta "password=" ~queda:[ "password=" ] Password "mysql --password=pinpan pun" "pinpan";
  redacta "password:" ~queda:[ "Password: " ] Password "Password: correcaballo" "correcaballo";
  let ent = "Zq8" ^ alnum in
  redacta "entropía" ~queda:[ "valor " ] Entropia ("valor " ^ ent) ent;
  (* Lo que no es secreto. *)
  intacto "sha de git" "commit 71bfb67a3c9e0d1f2b4a5c6d7e8f9012a3b4c5d6";
  intacto "ruta de nix" "/nix/store/5bh70sqlfys00x2g39xhv3i74x9jaa15-ocaml5.4.1-claude-costes-0.1.0";
  intacto "uuid" "sesión f2de5423-42a6-4c2f-b2e3-10c008c0204c";
  intacto "clave primaria" "PRIMARY KEY (sesion, uuid)";
  intacto "referencia a variable" "GITHUB_TOKEN=$GITHUB_TOKEN";
  intacto "prosa" "la key del problema es el token de sesión";
  intacto "sk- corto" "usa la opción sk-learn";
  intacto "sk- en una ruta" "https://tienda.de/sk-nvme-2tb-pcie-gen4-ssd-modelo-nuevo";
  intacto "CamelCase" "test VolumeOscillatorRanker10Test y ComprehensiveIndicator_10_20Test";
  intacto "ruta con hash" "export NODE_PATH=/nix/store/9abc1defgh2ijkl3mnop4qrst5uvwx6yz-node/lib";
  intacto "id de invocación" "inv_1abcDEF234ghiJKL567mnoPQR890stu";
  let k = "client=" ^ "aZ3" ^ "-" ^ alnum in
  redacta "entropía con separador" ~queda:[ "client=" ] Entropia k alnum;
  (* Huecos que encontró --residuos. *)
  let hex40 = "0123456789abcdef" ^ "0123456789abcdef" ^ "01234567" in
  redacta "palabra en medio de la variable" ~queda:[ "KEY_FOR_FORGEJO=" ] Clave ("KEY_FOR_FORGEJO=" ^ hex40) hex40;
  redacta "hex tras token (Forgejo)" ~queda:[ "el token de Forgejo es " ] Clave ("el token de Forgejo es " ^ hex40) hex40;
  redacta "hex tras API-Key" ~queda:[ "API-Key: " ] Clave ("curl -H 'API-Key: " ^ hex40 ^ "'") hex40;
  redacta "PEM en base64 tras SECRET" ~queda:[ "SECRET=" ] Clave ("SECRET=LS0t" ^ "LS1CRUdJTiBQUklWQVRF") "LS1CRUdJTi";
  redacta "apiKey = " ~queda:[ "apiKey = " ] Clave ("apiKey = \"" ^ alnum ^ "\"") alnum;
  intacto "hash de git tras commit" ("commit " ^ hex40 ^ " en master");
  intacto "ruta tras key_file" "key_file=/run/secrets/c1-wg.key";
  let sucio = "export API_TOKEN=" ^ alnum ^ " y LS0t" ^ "LS1CRUdJTiBQUklWQVRFIEtFWS0" in
  comprueba "residuos: los ve" (List.length (Residuos.buscar sucio) = 2);
  comprueba "residuos: nada tras redactar" (Residuos.buscar (fst (Redaccion.redactar sucio)) = []);
  comprueba "residuos: silueta, no valor"
    (List.for_all (fun (_, f) -> not (contiene f "Qx7b")) (Residuos.buscar sucio));
  (* Ronda 2: contraseñas en español, [pass] en nombres, órdenes e Infisical. *)
  redacta "la contraseña:" ~queda:[ "la contraseña: " ] Password "la contraseña: correcaballo" "correcaballo";
  redacta "contraseña=" ~queda:[ "contraseña=" ] Password "contraseña=pinpanpun" "pinpanpun";
  redacta "clave:" ~queda:[ "clave: " ] Password "la clave: pinpanpun" "pinpanpun";
  redacta "DB_PASS=" ~queda:[ "DB_PASS=" ] Password "DB_PASS=hunter22" "hunter22";
  redacta "mysql -pX" ~queda:[ "mysql -u root -p" ] Password "mysql -u root -phunter22 db" "hunter22";
  redacta "-p 'X'" ~queda:[ "-p " ] Password "pg -p 'hunter 22'" "hunter 22";
  redacta "sshpass -p" ~queda:[ "sshpass -p " ] Password "sshpass -p hunter22 ssh c1" "hunter22";
  redacta "curl -u" ~queda:[ "curl -u silvio:" ] Password "curl -u silvio:hunter22 https://x" "hunter22";
  redacta "--password X" ~queda:[ "--password " ] Password "rclone --password hunter22" "hunter22";
  redacta "--password=X" ~queda:[ "--password=" ] Password "rclone --password=hunter22" "hunter22";
  let st = "st." ^ "a1b2c3d4-e5f6-7890" ^ ".abcdef0123456789.fedcba98" in
  redacta "token de Infisical" ~queda:[ "usa " ] Infisical ("usa " ^ st) "abcdef0123";
  intacto "clave en prosa" "La clave: Infisical guarda los secretos";
  intacto "clave con negrita" "clave: **c1** manda";
  intacto "pass en prosa" "Pass: all tests green";
  redacta "PASS: al final" ~queda:[ "PASS: " ] Password "SMTP_PASS: hunter22" "hunter22";
  intacto "mkdir -p" "mkdir -p /tmp/x && ssh -p 22 c1";
  intacto "mkdir -p con comillas" "mkdir -p '/tmp/a b'";
  intacto "journalctl -u" "journalctl -u nginx --since today";
  intacto "uid en docker" "docker run -u 1000:1000 imagen";
  intacto "la palabra test." "un test.unitario_largo.otra_cosa_larga";
  (* La marca no se vuelve a redactar. *)
  let r1, _ = Redaccion.redactar ("A_TOKEN=" ^ gh) in
  let r2, c2 = Redaccion.redactar r1 in
  comprueba "idempotente" (r1 = r2 && c2 = [])

let linea j = Yojson.Safe.to_string j

let usuario ?(extra = []) contenido =
  linea
    (`Assoc
       ([ ("type", `String "user"); ("timestamp", `String "2026-10-13T10:00:00.123Z"); ("sessionId", `String "s1");
          ("uuid", `String "u1"); ("cwd", `String "/logical-node");
          ("message", `Assoc [ ("role", `String "user"); ("content", contenido) ]) ]
       @ extra))

let asistente bloques =
  linea
    (`Assoc
       [ ("type", `String "assistant"); ("timestamp", `String "2026-10-13T10:00:01Z"); ("sessionId", `String "s1");
         ("uuid", `String "u2"); ("cwd", `String "/logical-node"); ("agentId", `String "a9");
         ("message", `Assoc [ ("role", `String "assistant"); ("content", `List bloques) ]) ])

let texto l = Option.map (fun (m : Transcript.mensaje) -> m.texto) (Transcript.de_linea l)

let () =
  comprueba "usuario simple" (texto (usuario (`String "comprueba c1")) = Some "comprueba c1");
  comprueba "system-reminder fuera"
    (texto (usuario (`String "hola <system-reminder>\nno\n</system-reminder> mundo")) = Some "hola  mundo");
  comprueba "comando / fuera"
    (texto
       (usuario
          (`String
            "<command-name>/model</command-name>\n<command-message>model</command-message>\n<command-args>opus</command-args>"))
    = None);
  comprueba "salida de comando local fuera"
    (texto (usuario (`String "<local-command-stdout>Set model</local-command-stdout>")) = None);
  comprueba "bash-input se queda, su salida no"
    (texto (usuario (`String "<bash-input>ls</bash-input><bash-stdout>secreto</bash-stdout>")) = Some "ls");
  comprueba "notificación de tarea fuera"
    (texto (usuario (`String "<task-notification>\n<task-id>x</task-id>\n</task-notification>")) = None);
  comprueba "isMeta fuera" (texto (usuario ~extra:[ ("isMeta", `Bool true) ] (`String "caveat")) = None);
  comprueba "resumen de compactación fuera"
    (texto (usuario ~extra:[ ("isCompactSummary", `Bool true) ] (`String "resumen")) = None);
  comprueba "tool_result fuera"
    (texto
       (usuario
          (`List [ `Assoc [ ("type", `String "tool_result"); ("content", `String "salida con sk-ant-xxx") ] ]))
    = None);
  comprueba "interrupción fuera" (texto (usuario (`String "[Request interrupted by user]")) = None);
  comprueba "otros tipos fuera" (Transcript.de_linea {|{"type":"ai-title","aiTitle":"x","sessionId":"s"}|} = None);
  comprueba "no JSON" (Transcript.de_linea "{roto" = None);
  let tu nombre input = `Assoc [ ("type", `String "tool_use"); ("name", `String nombre); ("input", input) ] in
  let m =
    Transcript.de_linea
      (asistente
         [ `Assoc [ ("type", `String "thinking"); ("thinking", `String "pienso") ];
           `Assoc [ ("type", `String "text"); ("text", `String "Miro el disco.") ];
           tu "Bash" (`Assoc [ ("command", `String "df -h /secreto"); ("description", `String "Ver disco") ]);
           tu "Read" (`Assoc [ ("file_path", `String "/etc/hosts") ]);
           tu "Write" (`Assoc [ ("content", `String "largo\nlargo") ]) ])
  in
  (match m with
  | Some m ->
      comprueba "asistente: texto y herramientas"
        (m.texto = "Miro el disco.\n[herramienta Bash: Ver disco]\n[herramienta Read]\n[herramienta Write]");
      comprueba "asistente: rol y agente" (m.rol = "assistant" && m.agente = "a9" && m.proyecto = "/logical-node")
  | None -> comprueba "asistente: hay mensaje" false);
  (* Se redacta lo que dijo el usuario. *)
  (match Transcript.de_linea (usuario (`String ("usa INFISICAL_TOKEN=st.abcdefgh.12345"))) with
  | Some m -> comprueba "redacta en el mensaje" (m.redacciones = [ (Redaccion.Clave, 1) ] && not (contiene m.texto "abcdefgh"))
  | None -> comprueba "redacta: hay mensaje" false);
  (* La entrada de la herramienta no entra nunca; la descripción, cortada
     sin partir UTF-8. *)
  comprueba "sin description, solo el nombre"
    (Transcript.herramienta "Bash" (`Assoc [ ("command", `String "ls /secreto") ]) = "[herramienta Bash]");
  let larga = String.concat "" (List.init 150 (fun _ -> "ñ")) in
  let h = Transcript.herramienta "Bash" (`Assoc [ ("description", `String larga) ]) in
  comprueba "descripción cortada en UTF-8" (String.is_valid_utf_8 h && String.length h < 230);
  (* Truncado sin partir UTF-8. *)
  let largo = String.concat "" (List.init 5000 (fun _ -> "ñ")) in
  let t, sí = Transcript.truncar largo in
  comprueba "truncado" (sí && contiene t "[…truncado, 10000 bytes]");
  comprueba "truncado UTF-8" (String.is_valid_utf_8 t)

let () =
  comprueba "literal" (Tabla.literal "a'b\000c\\n" = "'a''bc\\n'");
  let m =
    { Transcript.ts = "2026-10-13T10:00:00Z"; sesion = "s"; uuid = "u"; agente = ""; proyecto = "/p"; rol = "user";
      texto = "it's"; redacciones = []; truncado = false }
  in
  let sql = Tabla.insertar ~nodo:"a1" [ m; m ] in
  comprueba "insert cita uuid" (contiene sql {|"uuid"|});
  comprueba "insert dos filas" (contiene sql "'it''s'),\n(");
  comprueba "lotes por filas" (List.map List.length (Tabla.lotes ~max_filas:2 [ m; m; m; m; m ]) = [ 2; 2; 1 ]);
  comprueba "lotes por bytes" (List.length (Tabla.lotes ~max_bytes:250 [ m; m; m ]) = 3);
  (* El cursor: líneas completas, reescritura y persistencia. *)
  let f = Filename.temp_file "memoria" ".jsonl" in
  Out_channel.with_open_bin f (fun oc -> output_string oc "uno\ndos\ntre");
  let ls, hasta = Ingesta.lineas_desde f 0 in
  comprueba "líneas completas" (ls = [ "uno"; "dos" ] && hasta = 8);
  let ls, _ = Ingesta.lineas_desde f hasta in
  comprueba "a medias, nada" (ls = []);
  let ls, _ = Ingesta.lineas_desde f 1000 in
  comprueba "fichero más corto: desde 0" (ls = [ "uno"; "dos" ]);
  let c = Cursor.vacio () in
  Cursor.fijar c "/a b\tc" 0;
  Cursor.fijar c "/x/y.jsonl" 42;
  let ruta = Filename.concat (Filename.get_temp_dir_name ()) (Printf.sprintf "memoria-%d/sub/cursor" (Unix.getpid ())) in
  comprueba "cursor se guarda" (Cursor.guardar ruta c = Ok ());
  comprueba "cursor: error sin excepción" (Result.is_error (Cursor.guardar "/proc/no/se/puede/cursor" c));
  let c' = Cursor.cargar ruta in
  comprueba "cursor persiste" (Cursor.desde c' "/x/y.jsonl" = 42 && Cursor.desde c' "/nada" = 0);
  if !fallos > 0 then (
    Printf.eprintf "%d fallos\n" !fallos;
    exit 1)
