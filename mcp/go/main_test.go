// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func codigo(r *respuesta) int {
	if r == nil || r.Error == nil {
		return 0
	}
	return r.Error.Code
}

func TestErroresDeProtocolo(t *testing.T) {
	s := &servidor{forja: nuevaForja("http://127.0.0.1:1")}
	casos := map[string]int{
		`esto no`:                    -32700,
		`[1,2]`:                      -32600,
		`{"jsonrpc":"2.0","id":7}`:   -32600,
		`{"id":7,"method":"no/hay"}`: -32601,
		`{"id":7,"method":"tools/call","params":{"name":"forja_semilla","arguments":{"tarea":"../x"}}}`: -32602,
		`{"id":7,"method":"tools/call","params":{"name":"Rara/../x","arguments":{"entrada":"x"}}}`:      -32602,
	}
	for linea, esperado := range casos {
		if c := codigo(s.atender([]byte(linea))); c != esperado {
			t.Errorf("%s: código %d, esperaba %d", linea, c, esperado)
		}
	}
	if r := s.atender([]byte(`{"jsonrpc":"2.0","method":"notifications/initialized"}`)); r != nil {
		t.Errorf("una notificación no lleva respuesta: %+v", r)
	}
}

func TestIDTalCual(t *testing.T) {
	s := &servidor{forja: nuevaForja("http://127.0.0.1:1")}
	r := s.atender([]byte(`{"id":"abc","method":"ping"}`))
	if string(r.ID) != `"abc"` {
		t.Errorf("id %s", r.ID)
	}
}

func TestMuestras(t *testing.T) {
	validos := map[string]int{`{}`: 5, `{"muestras":0}`: 0, `{"muestras":1000}`: 1000}
	for crudo, n := range validos {
		var a argumentos
		_ = json.Unmarshal([]byte(crudo), &a)
		if m, err := a.muestras(); err != nil || m != n {
			t.Errorf("%s: %d, %v", crudo, m, err)
		}
	}
	for _, crudo := range []string{`{"muestras":-1}`, `{"muestras":1001}`, `{"muestras":"dos"}`, `{"muestras":2.5}`} {
		var a argumentos
		_ = json.Unmarshal([]byte(crudo), &a)
		if _, err := a.muestras(); err == nil {
			t.Errorf("%s: debería fallar", crudo)
		}
	}
}

func TestCristal(t *testing.T) {
	forjaFalsa := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/forja/vitrina/mayus":
			w.Write([]byte(`{"salida":"HOLA"}`))
		case "/forja/vitrina/defectuoso":
			w.Write([]byte(`{"defecto":"dígitos"}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer forjaFalsa.Close()
	f := nuevaForja(forjaFalsa.URL)
	args := argumentos{"entrada": json.RawMessage(`"hola"`)}
	if r, err := llamar(f, "mayus", args); err != nil || r.IsError || r.Content[0].Text != "HOLA" {
		t.Errorf("salida: %+v %v", r, err)
	}
	if r, err := llamar(f, "defectuoso", args); err != nil || !r.IsError || !strings.HasPrefix(r.Content[0].Text, "defecto: ") {
		t.Errorf("defecto: %+v %v", r, err)
	}
	if _, err := llamar(f, "noexiste", args); err == nil {
		t.Errorf("404 debería ser -32602")
	}
}
