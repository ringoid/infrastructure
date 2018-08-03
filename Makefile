SERVICE_NAME = neo4jserver
VERSION = latest

IMAGE_TAG = 410568660038.dkr.ecr.eu-west-2.amazonaws.com/$(SERVICE_NAME):$(VERSION)

BUILD_ARGS=

all: deploy

build:
	@echo '--- Building neo4jserver Docker image ---'
	docker build $(BUILD_ARGS) -t $(IMAGE_TAG) .

login:
	@echo '--- Login into ECR ---'
	./ecr-login.sh

push: build login
	@echo '--- Push an-anonymizer docker image ---'
	docker push $(IMAGE_TAG)

deploy: clean push
	@echo 'Package neo4j-template'
	sam package --template-file neo4j-template.yaml --s3-bucket ringoid-cloudformation-templates --output-template-file neo4j-template-packaged.yaml
	@echo 'Deploy neo4j-stack'
	sam deploy --template-file neo4j-template-packaged.yaml --s3-bucket ringoid-cloudformation-templates --stack-name neo4j-stack --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset

clean:
	@echo 'Delete old artifacts'
	rm -rf neo4j-template-packaged.yaml
	@echo 'Finish with clean'



