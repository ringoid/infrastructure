package main

import (
	"context"
	basicLambda "github.com/aws/aws-lambda-go/lambda"
	"../sys_log"
	"os"
	"fmt"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambdacontext"
	"net/http"
	"errors"
	"encoding/json"
	"bytes"
)

var anlogger *syslog.Logger
var slackWebhookUrl string

func init() {
	var env string
	var ok bool
	var papertrailAddress string
	var err error

	env, ok = os.LookupEnv("ENV")
	if !ok {
		fmt.Printf("lambda-initialization : alarm_sender.go : env can not be empty ENV\n")
		os.Exit(1)
	}
	fmt.Printf("lambda-initialization : alarm_sender.go : start with ENV = [%s]\n", env)

	papertrailAddress, ok = os.LookupEnv("PAPERTRAIL_LOG_ADDRESS")
	if !ok {
		fmt.Printf("lambda-initialization : alarm_sender.go : env can not be empty PAPERTRAIL_LOG_ADDRESS\n")
		os.Exit(1)
	}
	fmt.Printf("lambda-initialization : alarm_sender.go : start with PAPERTRAIL_LOG_ADDRESS = [%s]\n", papertrailAddress)

	anlogger, err = syslog.New(papertrailAddress, fmt.Sprintf("%s-%s", env, "alarm-sender-infrastructure"))
	if err != nil {
		fmt.Errorf("lambda-initialization : alarm_sender.go : error during startup : %v\n", err)
		os.Exit(1)
	}
	anlogger.Debugf(nil, "lambda-initialization : alarm_sender.go : logger was successfully initialized")

	slackWebhookUrl, ok = os.LookupEnv("SLACK_WEBHOOK_URL")
	if !ok {
		anlogger.Fatalf(nil, "lambda-initialization : alarm_sender.go : slack webhook url can not be empty SLACK_WEBHOOK_URL\n")
	}
	anlogger.Debugf(nil, "lambda-initialization : alarm_sender.go : start with SLACK_WEBHOOK_URL = [%s]\n", slackWebhookUrl)
}

func handler(ctx context.Context, event events.SNSEvent) (error) {
	lc, _ := lambdacontext.FromContext(ctx)
	anlogger.Debugf(lc, "alarm_sender.go : start handle event %v", event)

	for _, record := range event.Records {
		message := record.SNS.Message

		anlogger.Debugf(lc, "alarm_sender.go : post [%s] message in a Slack")
		slackMessage := SlackMessage{
			Text: message,
		}
		body, err := json.Marshal(slackMessage)
		if err != nil {
			anlogger.Errorf(lc, "alarm_sender.go : error marshaling slack message %v : %v", slackMessage, err)
			return errors.New("error marshaling slack message")
		}
		req, err := http.NewRequest("POST", slackWebhookUrl, bytes.NewReader(body))

		if err != nil {
			anlogger.Errorf(lc, "alarm_sender.go : error while construct the request to send message into Slack : %v", err)
			return errors.New("error construct request to slack")
		}

		req.Header.Set("Content-Type", "application/json")

		client := &http.Client{}

		resp, err := client.Do(req)
		if err != nil {
			anlogger.Errorf(lc, "alarm_sender.go error while making request to Slack : %v", err)
			return errors.New("error sending request to slack")
		}
		defer resp.Body.Close()

		anlogger.Debugf(lc, "alarm_sender.go : successfully complete handle event %v", event)
	}

	return nil
}

func main() {
	basicLambda.Start(handler)
}

type SlackMessage struct {
	Text string `json:"text"`
}
