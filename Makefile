SERVICE_NAME = redisservice
VERSION = latest

IMAGE_TAG = 410568660038.dkr.ecr.eu-west-1.amazonaws.com/$(SERVICE_NAME):$(VERSION)

BUILD_ARGS=

stage-all: stage-deploy-analytics stage-deploy-stream zip_lambda stage-deploy-alarm stage-deploy-network
test-all: test-deploy-analytics test-deploy-stream zip_lambda test-deploy-alarm test-deploy-network
prod-all: prod-deploy-analytics prod-deploy-stream zip_lambda prod-deploy-alarm prod-deploy-network

build:
	@echo '--- Building alarm-sender-infrastrucutre function ---'
	GOOS=linux go build lambda-infrastructure-sender/alarm_sender.go

zip_lambda: build
	@echo '--- Zip alarm-sender-infrastrucutre function ---'
	zip alarm_sender.zip ./alarm_sender

build-redis-docker:
	@echo '--- Building redisservice Docker image ---'
	docker build $(BUILD_ARGS) -t $(IMAGE_TAG) .

login:
	@echo '--- Login into ECR ---'
	./ecr-login.sh

push: build-redis-docker login
	@echo '--- Push redis docker image ---'
	docker push $(IMAGE_TAG)

stage-deploy-neo4j: clean push
	@echo 'Package neo4j-template'
	sam package --template-file neo4j-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file neo4j-template-packaged.yaml
	@echo 'Deploy stage-neo4j-stack'
	sam deploy --template-file neo4j-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name stage-neo4j-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=stage --no-fail-on-empty-changeset

test-deploy-analytics: clean
	@echo 'Package analytics-template'
	sam package --template-file analytics-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file analytics-template-packaged.yaml
	@echo 'Deploy test-analytics-stack'
	sam deploy --template-file analytics-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name test-infrastructure-analytics-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=test --no-fail-on-empty-changeset

test-deploy-stream: clean
	@echo 'Package common-stream-template'
	sam package --template-file common-stream-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-stream-template-packaged.yaml
	@echo 'Deploy test-common-stream-stack'
	sam deploy --template-file common-stream-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name test-infrastructure-common-stream-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=test --no-fail-on-empty-changeset

test-deploy-alarm: clean
	@echo 'Package alarm-template'
	sam package --template-file alarm-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file alarm-template-packaged.yaml
	@echo 'Deploy test-alarm-stack'
	sam deploy --template-file alarm-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name test-infrastructure-alarm-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=test --no-fail-on-empty-changeset

test-deploy-network: clean
	@echo 'Package network-template'
	sam package --template-file common-network-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-network-template-packaged.yaml
	@echo 'Deploy network-alarm-stack'
	sam deploy --template-file common-network-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name test-network-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=test --no-fail-on-empty-changeset

test-deploy-cache: push clean
	@echo 'Package cache-template'
	sam package --template-file common-cache-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-cache-template-packaged.yaml
	@echo 'Deploy cache-stack'
	sam deploy --template-file common-cache-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name test-cache-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=test --no-fail-on-empty-changeset

stage-deploy-analytics: clean
	@echo 'Package analytics-template'
	sam package --template-file analytics-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file analytics-template-packaged.yaml
	@echo 'Deploy stage-analytics-stack'
	sam deploy --template-file analytics-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name stage-infrastructure-analytics-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=stage --no-fail-on-empty-changeset

stage-deploy-stream: clean
	@echo 'Package common-stream-template'
	sam package --template-file common-stream-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-stream-template-packaged.yaml
	@echo 'Deploy stage-common-stream-stack'
	sam deploy --template-file common-stream-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name stage-infrastructure-common-stream-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=stage --no-fail-on-empty-changeset

stage-deploy-alarm: clean
	@echo 'Package alarm-template'
	sam package --template-file alarm-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file alarm-template-packaged.yaml
	@echo 'Deploy stage-alarm-stack'
	sam deploy --template-file alarm-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name stage-infrastructure-alarm-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=stage --no-fail-on-empty-changeset

stage-deploy-network: clean
	@echo 'Package network-template'
	sam package --template-file common-network-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-network-template-packaged.yaml
	@echo 'Deploy network-alarm-stack'
	sam deploy --template-file common-network-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name stage-network-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=stage --no-fail-on-empty-changeset

stage-deploy-cache: push clean
	@echo 'Package cache-template'
	sam package --template-file common-cache-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-cache-template-packaged.yaml
	@echo 'Deploy cache-stack'
	sam deploy --template-file common-cache-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name stage-cache-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=stage --no-fail-on-empty-changeset


prod-deploy-analytics: clean
	@echo 'Package analytics-template'
	sam package --template-file analytics-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file analytics-template-packaged.yaml
	@echo 'Deploy prod-analytics-stack'
	sam deploy --template-file analytics-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name prod-infrastructure-analytics-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=prod --no-fail-on-empty-changeset

prod-deploy-stream: clean
	@echo 'Package common-stream-template'
	sam package --template-file common-stream-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-stream-template-packaged.yaml
	@echo 'Deploy prod-common-stream-stack'
	sam deploy --template-file common-stream-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name prod-infrastructure-common-stream-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=prod --no-fail-on-empty-changeset

prod-deploy-alarm: clean
	@echo 'Package alarm-template'
	sam package --template-file alarm-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file alarm-template-packaged.yaml
	@echo 'Deploy prod-alarm-stack'
	sam deploy --template-file alarm-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name prod-infrastructure-alarm-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=prod --no-fail-on-empty-changeset

prod-deploy-network: clean
	@echo 'Package network-template'
	sam package --template-file common-network-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-network-template-packaged.yaml
	@echo 'Deploy network-alarm-stack'
	sam deploy --template-file common-network-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name prod-network-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=prod --no-fail-on-empty-changeset

prod-deploy-cache: push clean
	@echo 'Package cache-template'
	sam package --template-file common-cache-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file common-cache-template-packaged.yaml
	@echo 'Deploy cache-stack'
	sam deploy --template-file common-cache-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name prod-cache-stack --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameter-overrides Env=prod --no-fail-on-empty-changeset

clean:
	@echo 'Delete old artifacts'
	rm -rf neo4j-template-packaged.yaml
	rm -rf analytics-template-packaged.yaml
	rm -rf common-stream-template-packaged.yaml
	rm -rf alarm-template-packaged.yaml
	rm -rf common-network-template-packaged.yaml
	rm -rf alarm_sender.zip
	rm -rf alarm_sender
	@echo 'Finish with clean'



