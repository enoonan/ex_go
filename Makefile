.PHONY: build_go

build_go:
	mkdir -p priv/bin
	go build -C go/go_ex -o ../../priv/bin/main

run_go:
	go run -C go/go_ex main.go $(API_KEY)

dev: 
	make build_go 
	iex -S mix phx.server