SERVICE_NAME = neo4jserver
VERSION = latest

IMAGE_TAG = 410568660038.dkr.ecr.eu-west-1.amazonaws.com/$(SERVICE_NAME):$(VERSION)

BUILD_ARGS=

all: stage-deploy-neo4j stage-deploy-analytics

build-neo4j-docker:
	@echo '--- Building neo4jserver Docker image ---'
	docker build $(BUILD_ARGS) -t $(IMAGE_TAG) .

login:
	@echo '--- Login into ECR ---'
	./ecr-login.sh

push: build-neo4j-docker login
	@echo '--- Push an-anonymizer docker image ---'
	docker push $(IMAGE_TAG)



stage-deploy-neo4j: clean push
	@echo 'Package neo4j-template'
	sam package --template-file neo4j-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file neo4j-template-packaged.yaml
	@echo 'Deploy stage-neo4j-stack'
	sam deploy --template-file neo4j-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name stage-neo4j-stack --capabilities CAPABILITY_IAM --parameter-overrides Env=stage --no-fail-on-empty-changeset

stage-deploy-analytics: clean
	@echo 'Package analytics-template'
	sam package --template-file analytics-template.yaml --s3-bucket ringoid-cloudformation-template --output-template-file analytics-template-packaged.yaml
	@echo 'Deploy stage-analytics-stack'
	sam deploy --template-file analytics-template-packaged.yaml --s3-bucket ringoid-cloudformation-template --stack-name stage-analytics-stack --capabilities CAPABILITY_IAM --parameter-overrides Env=stage --no-fail-on-empty-changeset

clean:
	@echo 'Delete old artifacts'
	rm -rf neo4j-template-packaged.yaml
	rm -rf analytics-template-packaged.yaml
	@echo 'Finish with clean'



