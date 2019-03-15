package main

import (
	"context"
	basicLambda "github.com/aws/aws-lambda-go/lambda"
	"fmt"
	"net/http"
	"bytes"
	"io/ioutil"
	"encoding/json"
	"github.com/aws/aws-lambda-go/lambdacontext"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/aws"
	"os"
	"github.com/aws/aws-sdk-go/service/elbv2"
	"github.com/aws/aws-sdk-go/service/lambda"
	"github.com/ringoid/commons"
)

type CustomRequest struct {
	RequestType        string            `json:"RequestType"`
	ResponseURL        string            `json:"ResponseURL"`
	StackId            string            `json:"StackId"`
	RequestId          string            `json:"RequestId"`
	ResourceType       string            `json:"ResourceType"`
	LogicalResourceId  string            `json:"LogicalResourceId"`
	ResourceProperties map[string]string `json:"ResourceProperties"`
}

func (obj CustomRequest) String() string {
	return fmt.Sprintf("%#v", obj)
}

type CustomResponse struct {
	Status             string            `json:"Status"`
	PhysicalResourceId string            `json:"PhysicalResourceId"`
	StackId            string            `json:"StackId"`
	RequestId          string            `json:"RequestId"`
	LogicalResourceId  string            `json:"LogicalResourceId"`
	Data               map[string]string `json:"Data"`
}

func (obj CustomResponse) String() string {
	return fmt.Sprintf("%#v", obj)
}

var elbClient *elbv2.ELBV2
var lambdaClient *lambda.Lambda

func init() {
	awsSession, err := session.NewSession(aws.NewConfig().
		WithRegion(commons.Region).WithMaxRetries(commons.MaxRetries))
	if err != nil {
		fmt.Printf("error during aws session initialization")
		os.Exit(1)
	}

	elbClient = elbv2.New(awsSession)
	lambdaClient = lambda.New(awsSession)
}

func handler(ctx context.Context, request CustomRequest) (error) {
	lc, _ := lambdacontext.FromContext(ctx)
	fmt.Printf("receive request : %v", request)

	var targetGroupArnStr string
	var err error
	responseStatus := "SUCCESS"

	if request.RequestType != "Delete" {
		targetGroupArnStr, err = targetGroupArn(request)
		if err != nil {
			responseStatus = "FAILED"
		}
	}

	response :=
		CustomResponse{
			Status:             responseStatus,
			PhysicalResourceId: lc.AwsRequestID,
			StackId:            request.StackId,
			RequestId:          request.RequestId,
			LogicalResourceId:  request.LogicalResourceId,
			Data: map[string]string{
				"TargetGroupArn": targetGroupArnStr,
			},
		}

	err = writeResponseInS3(request, response)
	return err
}

func writeResponseInS3(request CustomRequest, response CustomResponse) error {
	fmt.Printf("write response to the destination : %v", response)

	arr, err := json.Marshal(response)
	if err != nil {
		fmt.Printf("error marshaling response %v : %v", response, err)
		return err
	}
	err = makePutRequestWithContent(request.ResponseURL, arr)
	if err != nil {
		fmt.Printf("error sending response %v : %v", response, err)
		return err
	}
	return nil
}

func makePutRequestWithContent(url string, source []byte) error {
	request, err := http.NewRequest("PUT", url, bytes.NewReader(source))
	if err != nil {
		return err
	}

	client := &http.Client{}
	httpResponse, err := client.Do(request)
	if err != nil {
		return err
	}
	defer httpResponse.Body.Close()

	_, err = ioutil.ReadAll(httpResponse.Body)
	if err != nil {
		return err
	}

	if httpResponse.StatusCode != 200 {
		return fmt.Errorf("error making put request with content, url [%s],  status code [%d]", url, httpResponse.StatusCode)
	}

	return nil
}

func targetGroupArn(request CustomRequest) (string, error) {

	input := &elbv2.CreateTargetGroupInput{
		Name:                       aws.String(request.ResourceProperties["CustomName"]),
		HealthCheckEnabled:         aws.Bool(true),
		HealthCheckIntervalSeconds: aws.Int64(300),
		HealthCheckTimeoutSeconds:  aws.Int64(10),
		HealthyThresholdCount:      aws.Int64(2),
		UnhealthyThresholdCount:    aws.Int64(2),
		TargetType:                 aws.String("lambda"),
	}
	result, err := elbClient.CreateTargetGroup(input)
	if err != nil {
		fmt.Printf("error creating TargetGroup for ALB : %v", err)
		return "", err
	}

	targetGroupArn := *result.TargetGroups[0].TargetGroupArn

	inputPerm := &lambda.AddPermissionInput{
		Action:       aws.String("lambda:InvokeFunction"),
		FunctionName: aws.String(request.ResourceProperties["TargetLambdaFunctionName"]),
		Principal:    aws.String("elasticloadbalancing.amazonaws.com"),
		SourceArn:    aws.String(targetGroupArn),
		StatementId:  aws.String("ST-ID-1"),
	}

	_, err = lambdaClient.AddPermission(inputPerm)
	if err != nil {
		fmt.Printf("error add permision to principal : %v", err)
		return "", err
	}

	inputR := &elbv2.RegisterTargetsInput{
		TargetGroupArn: aws.String(targetGroupArn),
		Targets: []*elbv2.TargetDescription{
			{
				Id: aws.String(request.ResourceProperties["CustomTargetsId"]),
			},
		},
	}

	_, err = elbClient.RegisterTargets(inputR)
	if err != nil {
		fmt.Printf("error registering Targets for TargetGroup : %v", err)
		return "", err
	}

	return targetGroupArn, nil
}

func main() {
	basicLambda.Start(handler)
}
