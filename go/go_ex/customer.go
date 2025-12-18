package main

import (
	"github.com/stripe/stripe-go/v84"
	"github.com/stripe/stripe-go/v84/customer"
)

func GetCustomer(data Input) ([]byte, error) {
	return handleCustomerResponse(func() (*stripe.Customer, error) {
		params := &stripe.CustomerParams{}
		stripeId := data["stripe_id"]
		return customer.Get(stripeId, params)
	})
}

func NewCustomer(data Input) ([]byte, error) {
	return handleCustomerResponse(func() (*stripe.Customer, error) {
		params := &stripe.CustomerParams{
			Description:      stripe.String(data["description"]),
			Email:            stripe.String(data["email"]),
			PreferredLocales: stripe.StringSlice([]string{"en", "es"}),
		}
		return customer.New(params)
	})
}

func handleCustomerResponse(callable func() (*stripe.Customer, error)) ([]byte, error) {
	c, err := callable()
	if err != nil {
		return nil, err
	}
	return c.LastResponse.RawJSON, nil
}
