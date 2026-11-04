package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/redis/go-redis/v9"
)

func TestNewRedisClientStandalone(t *testing.T) {
	client, err := newRedisClient("redis://localhost:6379", false)
	if err != nil {
		t.Fatalf("newRedisClient retornou erro: %v", err)
	}
	defer func() { _ = client.Close() }()
	if _, ok := client.(*redis.Client); !ok {
		t.Fatalf("esperava *redis.Client, recebeu %T", client)
	}
}

func TestNewRedisClientClusterTLS(t *testing.T) {
	client, err := newRedisClient("rediss://:token@cluster.example.com:6379", true)
	if err != nil {
		t.Fatalf("newRedisClient retornou erro: %v", err)
	}
	defer func() { _ = client.Close() }()
	if _, ok := client.(*redis.ClusterClient); !ok {
		t.Fatalf("esperava *redis.ClusterClient, recebeu %T", client)
	}
}

func TestNewRedisClientRejectsInvalidClusterURL(t *testing.T) {
	if _, err := newRedisClient("http://cluster.example.com:6379", true); err == nil {
		t.Fatal("esperava erro para esquema inválido")
	}
}

func TestFetchFlagEscapaNomeNaURL(t *testing.T) {
	var path string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path = r.URL.EscapedPath()
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{}`))
	}))
	defer srv.Close()

	a := &App{FlagServiceURL: srv.URL, HttpClient: srv.Client()}
	if _, err := a.fetchFlag("../admin?x=1"); err != nil {
		t.Fatalf("fetchFlag retornou erro: %v", err)
	}
	if want := "/flags/..%2Fadmin%3Fx=1"; path != want {
		t.Fatalf("caminho = %q, esperava %q", path, want)
	}
}
