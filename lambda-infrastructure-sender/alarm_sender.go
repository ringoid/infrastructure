package main

import (
	"context"
	basicLambda "github.com/aws/aws-lambda-go/lambda"
	"../sys_log"
	"os"
	"fmt"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambdacontext"
)

var anlogger *syslog.Logger

func init() {
	var env string
	var ok bool
	var papertrailAddress string
	var err error

	env, ok = os.LookupEnv("ENV")
	if !ok {
		fmt.Printf("alarm_sender.go : env can not be empty ENV")
		os.Exit(1)
	}
	fmt.Printf("alarm_sender.go : start with ENV = [%s]", env)

	papertrailAddress, ok = os.LookupEnv("PAPERTRAIL_LOG_ADDRESS")
	if !ok {
		fmt.Printf("alarm_sender.go : env can not be empty PAPERTRAIL_LOG_ADDRESS")
		os.Exit(1)
	}
	fmt.Printf("alarm_sender.go : start with PAPERTRAIL_LOG_ADDRESS = [%s]", papertrailAddress)

	anlogger, err = syslog.New(papertrailAddress, fmt.Sprintf("%s-%s", env, "alarm-sender-infrastructure"))
	if err != nil {
		fmt.Errorf("alarm_sender.go : error during startup : %v", err)
		os.Exit(1)
	}
	anlogger.Debugf(nil, "alarm_sender.go : logger was successfully initialized")
}

func handler(ctx context.Context, event events.SNSEvent) (error) {
	lc, _ := lambdacontext.FromContext(ctx)
	anlogger.Debugf(lc, "alarm_sender.go : start handle event %v", event)
	anlogger.Debugf(lc, "alarm_sender.go : successfully complete handle event %v", event)
	return nil
}

func main() {
	basicLambda.Start(handler)
}
