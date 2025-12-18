# ExGo

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Run `make dev` to build the Go code and start the server locally

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Next, get all set up with Stripe, including logging into the Stripe CLI. Then:
* Run `stripe listen --forward-to localhost:4000/webhooks/stripe` 

Check out: 
* `ExGoWeb.StripeWebhookController`
* `ExGoWeb.ParsersWithRawBody` (ripped shamelessly from the Dashbit blog)
* `GoRunner` in `lib/ex_go/go_runner.ex`
* everything in `go/go_ex` 

In iex, try:
```
> GoRunner.send_command("new_customer", %{email: "foo@bar.com", description: "bazz buzz"})
> GoRunner.send_command("get_customer", %{stripe_id: "cust_1234asdf"})
```

### What is this??
It's an experiment to scratch an itch I had. I was feeling consternations about not using an officially supported Stripe SDK and I thought, "hmm, Go compiles to a binary, wouldn't it be neat to just call out to Stripe's Go SDK?"

I've since decided to [just use Req](https://dashbit.co/blog/sdks-with-req-stripe).

Nonetheless! Itches need scratching. The version you see here uses a module called `GoRunner` which uses `System.cmd` to shell out to the Go binary. That's the simplest approach, but it does seem to incur about a 40ms startup cost for each command. 

I had another version that wrapped a long running Go process in a GenServer with [Ports](https://hexdocs.pm/elixir/Port.html). That was quite snappy, and if the Go process crashed, so too would the GenServer, and both would simply be restarted by the app. 

But it's a bit more complex to manage. If you have a huge spike, that GenServer could become a bottleneck, so you might want to manage a pool of them. However, it does seem unlikely for most apps to ever get hundreds of Stripe requests per second. At that point you'll have bigger problems.

Here is the GenServer version of `GoRunner`:

```elixir
defmodule GoRunner do
  use GenServer
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  def send_command(command, %{} = data \\ %{}) do
    GenServer.call(__MODULE__, {:command, command, data})
  end
  def init(_) do
    binary_path = Application.app_dir(:ex_go, "priv/bin/main")
    api_key = Application.get_env(:ex_go, :stripe_secret)
    port = Port.open({:spawn, "#{binary_path} #{api_key}"}, [:binary, :exit_status])
    {:ok, %{port: port}}
  end
  def handle_call({:command, command, data}, _from, state) do
    data_str = Jason.encode!(data)

    Port.command(state.port, "#{command} #{data_str}\n")

    receive do
      {port, {:data, data}} when port == state.port ->
        case data |> String.trim() |> Jason.decode!() do
          %{"ok" => payload} ->
            {:reply, {:ok, payload |> String.trim() |> Jason.decode!()}, state}
          %{"error" => payload} ->
            {:reply, {:error, payload |> String.trim()}, state}
        end
      {port, {:exit_status, status}} when port == state.port ->
        send(self(), {port, {:exit_status, status}})
        {:reply, {:error, "Process exited with status #{status}"}, state}
      foo ->
        {:reply, {:ok, foo}, state}
    after
      5000 ->
        {:reply, {:error, :timeout}, state}
    end
  end
  def handle_info({port, {:exit_status, _status}}, %{port: port} = state) do
    {:stop, :normal, state}
  end
  def handle_info({port, info}, state) do
    IO.inspect({port, info})
    {:noreply, state}
  end
end
```

And here is the `main.go` code for that version:

```go
package main
import (
    "bufio"
    "encoding/json"
    "fmt"
    "os"
    "strings"
    "github.com/stripe/stripe-go/v84"
)
func main() {
    if len(os.Args) < 2 {
        fmt.Println("API key is required")
        os.Exit(1)
    }
    key := os.Args[1]
    stripe.Key = key
    scanner := bufio.NewScanner(os.Stdin)
    for {
        if !scanner.Scan() {
            break
        }
        input := strings.TrimSpace(scanner.Text())
        if input == "exit" {
            fmt.Println("Goodbye!")
            break
        }
        parts := strings.SplitN(input, " ", 2)
        command := parts[0]
        var data Input
        if len(parts) == 2 {
            raw_data := []byte(parts[1])
            err := json.Unmarshal(raw_data, &data)
            if err != nil {
                fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
            }
        }
        processCommand(command, data)
    }
    if err := scanner.Err(); err != nil {
        fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
    }
}
func processCommand(command string, data Input) {
    result, err := runCommand(command, data)
    if err != nil {
        errOut(command, err)
    } else {
        successOutput(result)
    }
}
func runCommand(command string, data Input) ([]byte, error) {
    switch command {
    case "hello":
        return json.Marshal(map[string]string{"ok": "Hello from Go!"})
    case "new_customer":
        return NewCustomer(data)
    case "get_customer":
        return GetCustomer(data)
    case "verify_webhook":
        return VerifyWebhook(data)
    }
    return nil, fmt.Errorf("unknown command: %s", command)
}
func errOut(func_call string, err error) {
    result, _ := json.Marshal(map[string]string{"error": "error running " + func_call + ": " + err.Error()})
    fmt.Fprintf(os.Stdout, "%s", result)
}
func successOutput(o []byte) {
    result, _ := json.Marshal(map[string]string{"ok": string(o)})
    fmt.Fprintf(os.Stdout, "%s", string(result))
}
```

### Isn't this a deployment nightmare??
I understand the concern, but I still don't see it as a huge problem. I manage all this locally with a Makefile:

```
.PHONY: build_go

build_go:
	mkdir -p priv/bin
	go build -C go/go_ex -o ../../priv/bin/main

run_go:
	go run -C go/go_ex main.go $(API_KEY)

dev: 
	make build_go 
	iex -S mix phx.server
```

`make dev` spins up the server with a fresh built Go binary ready to roll. Go compiles fast!

I'd use similar code in a Dockerfile. The difference would be I'd need to specify a GOOS and/or GOARCH that corresponds to the machine I'm building. I don't see that as a huge challenge, but maybe some folks do.  

## Conclusion

I'm still just going to use Req to interact with the Stripe API from Elixir. But maybe someday I'll have a need to use some embedded Go binary in an Elixir app. And if that day comes, I shan't fear. 
