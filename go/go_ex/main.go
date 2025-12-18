package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/stripe/stripe-go/v84"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "Usage: %s <api_key> <command> [json_data]\n", os.Args[0])
		os.Exit(1)
	}

	apiKey := os.Args[1]
	command := os.Args[2]

	stripe.Key = apiKey

	var data Input
	if len(os.Args) >= 4 {
		rawData := []byte(os.Args[3])
		if err := json.Unmarshal(rawData, &data); err != nil {
			errOut(command, fmt.Errorf("invalid JSON data: %w", err))
			os.Exit(1)
		}
	}

	result, err := runCommand(command, data)
	if err != nil {
		errOut(command, err)
		os.Exit(1)
	}

	successOutput(result)
}

func runCommand(command string, data Input) ([]byte, error) {
	switch command {
	case "hello":
		return json.Marshal(map[string]string{"message": "Hello from Go!"})
	case "new_customer":
		return NewCustomer(data)
	case "get_customer":
		return GetCustomer(data)
	case "verify_webhook":
		return VerifyWebhook(data)
	default:
		return nil, fmt.Errorf("unknown command: %s", command)
	}
}

func errOut(funcCall string, err error) {
	result := map[string]string{
		"error": fmt.Sprintf("error running %s: %s", funcCall, err.Error()),
	}
	output, _ := json.Marshal(result)
	fmt.Fprintf(os.Stderr, "%s\n", output)
}

func successOutput(data []byte) {
	result := map[string]interface{}{
		"ok": json.RawMessage(data),
	}
	output, _ := json.Marshal(result)
	fmt.Println(string(output))
}
