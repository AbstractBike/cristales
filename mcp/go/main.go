// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

// forja-mcp: servidor MCP (stdio, un mensaje JSON-RPC por línea) que pone la
// forja al alcance de un agente. Cumple mcp/CONTRATO.md.
package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
)

const (
	nombreServidor  = "forja-mcp"
	versionServidor = "0.2.0"
	forjaPorDefecto = "http://[b1c1:a2::1]:8090"
)

var versiones = []string{"2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"}

// errorRPC es un error JSON-RPC con su código.
type errorRPC struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *errorRPC) Error() string { return e.Message }

func invalidos(formato string, a ...any) error {
	return &errorRPC{Code: -32602, Message: fmt.Sprintf(formato, a...)}
}

type respuesta struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id"`
	Result  any             `json:"result,omitempty"`
	Error   *errorRPC       `json:"error,omitempty"`
}

var idNulo = json.RawMessage("null")

func fallo(id json.RawMessage, codigo int, mensaje string) *respuesta {
	return &respuesta{JSONRPC: "2.0", ID: id, Error: &errorRPC{Code: codigo, Message: mensaje}}
}

type servidor struct{ forja *forja }

// atender procesa una línea y devuelve la respuesta, o nil si no la lleva.
func (s *servidor) atender(linea []byte) *respuesta {
	if !json.Valid(linea) {
		return fallo(idNulo, -32700, "la línea no es JSON")
	}
	var msg map[string]json.RawMessage
	if err := json.Unmarshal(linea, &msg); err != nil || msg == nil {
		return fallo(idNulo, -32600, "el mensaje no es un objeto")
	}
	id, conID := msg["id"]
	if !conID || string(id) == "null" {
		return nil // notificación
	}
	var metodo string
	if err := json.Unmarshal(msg["method"], &metodo); err != nil || msg["method"] == nil {
		return fallo(id, -32600, "falta method")
	}
	res, err := s.despachar(metodo, msg["params"])
	if err != nil {
		var e *errorRPC
		if errors.As(err, &e) {
			return fallo(id, e.Code, e.Message)
		}
		return fallo(id, -32603, err.Error())
	}
	return &respuesta{JSONRPC: "2.0", ID: id, Result: res}
}

func (s *servidor) despachar(metodo string, params json.RawMessage) (any, error) {
	switch metodo {
	case "initialize":
		return inicializar(params), nil
	case "ping":
		return struct{}{}, nil
	case "tools/list":
		return map[string]any{"tools": listar(s.forja)}, nil
	case "tools/call":
		return s.llamar(params)
	default:
		return nil, &errorRPC{Code: -32601, Message: metodo + ": método desconocido"}
	}
}

func inicializar(params json.RawMessage) any {
	var p struct {
		ProtocolVersion string `json:"protocolVersion"`
	}
	_ = json.Unmarshal(params, &p)
	version := versiones[0]
	for _, v := range versiones {
		if v == p.ProtocolVersion {
			version = v
		}
	}
	return map[string]any{
		"protocolVersion": version,
		"capabilities":    map[string]any{"tools": map[string]any{}},
		"serverInfo":      map[string]string{"name": nombreServidor, "version": versionServidor},
	}
}

func (s *servidor) llamar(params json.RawMessage) (any, error) {
	var p struct {
		Name      *string         `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.Name == nil {
		return nil, invalidos("tools/call: falta name (texto)")
	}
	args := argumentos{}
	if len(p.Arguments) > 0 && string(p.Arguments) != "null" {
		if err := json.Unmarshal(p.Arguments, &args); err != nil {
			return nil, invalidos("tools/call: arguments tiene que ser un objeto")
		}
	}
	return llamar(s.forja, *p.Name, args)
}

func main() {
	log.SetFlags(0)
	log.SetOutput(os.Stderr)
	raiz := os.Getenv("FORJA_URL")
	if raiz == "" {
		raiz = forjaPorDefecto
	}
	s := &servidor{forja: nuevaForja(raiz)}
	log.Printf("forja-mcp %s: forja en %s", versionServidor, raiz)

	entrada := bufio.NewReaderSize(os.Stdin, 1<<20)
	salida := bufio.NewWriter(os.Stdout)
	codificador := json.NewEncoder(salida)
	codificador.SetEscapeHTML(false)
	for {
		linea, err := entrada.ReadBytes('\n')
		if l := strings.TrimSpace(string(linea)); l != "" {
			if r := s.atender([]byte(l)); r != nil {
				if e := codificador.Encode(r); e != nil {
					log.Printf("forja-mcp: no puedo codificar la respuesta: %v", e)
				}
				if e := salida.Flush(); e != nil {
					log.Printf("forja-mcp: stdout cerrado: %v", e)
					return
				}
			}
		}
		if err == io.EOF {
			return
		}
		if err != nil {
			log.Printf("forja-mcp: error leyendo stdin: %v", err)
			return
		}
	}
}
