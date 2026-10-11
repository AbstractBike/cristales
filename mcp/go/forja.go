// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

package main

// El cliente HTTP de la API de introspección de la forja (/forja/…).
// No interpreta nada: devuelve estado y cuerpo, o el error de transporte.

import (
	"bytes"
	"io"
	"net/http"
	"strings"
	"time"
)

type forja struct {
	raiz    string
	cliente *http.Client
}

func nuevaForja(raiz string) *forja {
	return &forja{
		raiz:    strings.TrimRight(raiz, "/"),
		cliente: &http.Client{Timeout: 30 * time.Second},
	}
}

func (f *forja) get(ruta string) (int, []byte, error) {
	return f.hacer(http.MethodGet, ruta, nil)
}

func (f *forja) post(ruta string, cuerpo []byte) (int, []byte, error) {
	return f.hacer(http.MethodPost, ruta, cuerpo)
}

func (f *forja) hacer(metodo, ruta string, cuerpo []byte) (int, []byte, error) {
	var lector io.Reader
	if cuerpo != nil {
		lector = bytes.NewReader(cuerpo)
	}
	req, err := http.NewRequest(metodo, f.raiz+ruta, lector)
	if err != nil {
		return 0, nil, err
	}
	if cuerpo != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := f.cliente.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	datos, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, nil, err
	}
	return resp.StatusCode, datos, nil
}
