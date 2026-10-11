// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

package main

// Las herramientas: las cuatro fijas, una por cristal de la vitrina, su
// validación y cómo se traduce cada llamada a la API de la forja.

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"regexp"
)

var patronTarea = regexp.MustCompile(`^[a-z0-9-]{1,64}$`)

const muestrasPorDefecto = 5

type esquema struct {
	Type       string                    `json:"type"`
	Properties map[string]map[string]any `json:"properties"`
	Required   []string                  `json:"required,omitempty"`
}

type herramienta struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	InputSchema esquema `json:"inputSchema"`
}

// resultado es el de tools/call: un bloque de texto y si es un error.
type resultado struct {
	Content []bloque `json:"content"`
	IsError bool     `json:"isError"`
}

type bloque struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

func texto(s string, esError bool) resultado {
	return resultado{Content: []bloque{{Type: "text", Text: s}}, IsError: esError}
}

var propTarea = map[string]any{"type": "string", "description": "Nombre de la tarea en la forja."}

var fijas = []herramienta{
	{
		Name:        "forja_tareas",
		Description: "Tareas que han pasado por la forja: fase (liquida, mixta o cristalina), muestras en la cantera, contrastes, coincidencias y si ya está madura para nuclear.",
		InputSchema: esquema{Type: "object", Properties: map[string]map[string]any{}},
	},
	{
		Name:        "forja_tarea",
		Description: "Detalle de una tarea de la forja: su informe, su plantilla (las instrucciones fijas) y sus últimas muestras de la cantera.",
		InputSchema: esquema{Type: "object", Properties: map[string]map[string]any{
			"tarea":    propTarea,
			"muestras": {"type": "integer", "minimum": 0, "maximum": 1000, "default": muestrasPorDefecto},
		}, Required: []string{"tarea"}},
	},
	{
		Name:        "forja_semilla",
		Description: "SEMILLA.md de una tarea: la plantilla y las muestras de la cantera, en el formato con el que se nuclea un cristal.",
		InputSchema: esquema{Type: "object", Properties: map[string]map[string]any{"tarea": propTarea}, Required: []string{"tarea"}},
	},
	{
		Name:        "forja_nucleacion",
		Description: "Prompt de nucleación de una tarea: lo que se le pide al LLM para que escriba el cristal (el método, no el resultado).",
		InputSchema: esquema{Type: "object", Properties: map[string]map[string]any{"tarea": propTarea}, Required: []string{"tarea"}},
	},
}

func cristal(tarea, descripcion string) herramienta {
	return herramienta{
		Name:        tarea,
		Description: descripcion,
		InputSchema: esquema{Type: "object", Properties: map[string]map[string]any{
			"entrada": {"type": "string"},
		}, Required: []string{"entrada"}},
	}
}

// listar da las fijas y, detrás, los cristales de la vitrina en su orden.
// Si la forja no responde, solo las fijas.
func listar(f *forja) []herramienta {
	todas := append([]herramienta{}, fijas...)
	estado, cuerpo, err := f.get("/forja/vitrina")
	if err != nil || estado/100 != 2 {
		log.Printf("forja-mcp: vitrina no disponible (estado %d, %v); solo las fijas", estado, err)
		return todas
	}
	var piezas []struct {
		Tarea       string `json:"tarea"`
		Descripcion string `json:"descripcion"`
	}
	if err := json.Unmarshal(cuerpo, &piezas); err != nil {
		log.Printf("forja-mcp: vitrina ilegible: %v; solo las fijas", err)
		return todas
	}
	for _, p := range piezas {
		if !patronTarea.MatchString(p.Tarea) {
			log.Printf("forja-mcp: cristal con nombre no válido, se omite: %q", p.Tarea)
			continue
		}
		todas = append(todas, cristal(p.Tarea, p.Descripcion))
	}
	return todas
}

// argumentos son los de tools/call, sin decodificar todavía.
type argumentos map[string]json.RawMessage

func (a argumentos) cadena(nombre string) (string, error) {
	crudo, ok := a[nombre]
	if !ok {
		return "", invalidos("falta el argumento %s", nombre)
	}
	var s string
	if err := json.Unmarshal(crudo, &s); err != nil {
		return "", invalidos("%s tiene que ser un texto", nombre)
	}
	return s, nil
}

func (a argumentos) tarea() (string, error) {
	t, err := a.cadena("tarea")
	if err != nil {
		return "", err
	}
	if !patronTarea.MatchString(t) {
		return "", invalidos("tarea no válida: %q (tiene que cumplir %s)", t, patronTarea)
	}
	return t, nil
}

func (a argumentos) muestras() (int, error) {
	crudo, ok := a["muestras"]
	if !ok {
		return muestrasPorDefecto, nil
	}
	var n float64
	if err := json.Unmarshal(crudo, &n); err != nil || n != math.Trunc(n) || n < 0 || n > 1000 {
		return 0, invalidos("muestras tiene que ser un entero entre 0 y 1000")
	}
	return int(n), nil
}

// llamar ejecuta una herramienta. Los errores devueltos son de protocolo
// (-32602); los fallos de la forja van dentro del resultado, con isError.
func llamar(f *forja, nombre string, args argumentos) (resultado, error) {
	switch nombre {
	case "forja_tareas":
		return fija(f, "/forja/tareas"), nil
	case "forja_tarea":
		t, err := args.tarea()
		if err != nil {
			return resultado{}, err
		}
		n, err := args.muestras()
		if err != nil {
			return resultado{}, err
		}
		return fija(f, fmt.Sprintf("/forja/tareas/%s?muestras=%d", t, n)), nil
	case "forja_semilla", "forja_nucleacion":
		t, err := args.tarea()
		if err != nil {
			return resultado{}, err
		}
		sufijo := map[string]string{"forja_semilla": "semilla", "forja_nucleacion": "nucleacion"}[nombre]
		return fija(f, "/forja/tareas/"+t+"/"+sufijo), nil
	default:
		return aplicarCristal(f, nombre, args)
	}
}

func fija(f *forja, ruta string) resultado {
	estado, cuerpo, err := f.get(ruta)
	if err != nil {
		return texto("forja: no responde: "+err.Error(), true)
	}
	if estado/100 != 2 {
		return texto(fmt.Sprintf("forja: GET %s → %d: %s", ruta, estado, cuerpo), true)
	}
	return texto(string(cuerpo), false)
}

func aplicarCristal(f *forja, nombre string, args argumentos) (resultado, error) {
	if !patronTarea.MatchString(nombre) {
		return resultado{}, invalidos("herramienta desconocida: %q", nombre)
	}
	entrada, err := args.cadena("entrada")
	if err != nil {
		return resultado{}, err
	}
	peticion, _ := json.Marshal(map[string]string{"entrada": entrada})
	ruta := "/forja/vitrina/" + nombre
	estado, cuerpo, err := f.post(ruta, peticion)
	switch {
	case err != nil:
		return texto("forja: no responde: "+err.Error(), true), nil
	case estado == http.StatusNotFound:
		return resultado{}, invalidos("%s: no hay tal cristal en la vitrina", nombre)
	case estado != http.StatusOK:
		return texto(fmt.Sprintf("forja: POST %s → %d: %s", ruta, estado, cuerpo), true), nil
	}
	var r struct {
		Salida  *string `json:"salida"`
		Defecto *string `json:"defecto"`
	}
	if err := json.Unmarshal(cuerpo, &r); err != nil {
		return texto("forja: respuesta ilegible: "+err.Error(), true), nil
	}
	switch {
	case r.Salida != nil:
		return texto(*r.Salida, false), nil
	case r.Defecto != nil:
		return texto("defecto: "+*r.Defecto, true), nil
	default:
		return texto(fmt.Sprintf("forja: respuesta sin salida ni defecto: %s", cuerpo), true), nil
	}
}
