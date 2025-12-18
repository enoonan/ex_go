package main

import (
	"encoding/json"
	"fmt"

	"github.com/stripe/stripe-go/webhook"
)

func VerifyWebhook(data Input) ([]byte, error) {
	_, err := webhook.ConstructEvent([]byte(data["payload"]), data["signature"], data["secret"])
	if err != nil {
		return nil, fmt.Errorf("verification_failed")
	}
	return json.Marshal(map[string]string{"status": "verified"})
}
