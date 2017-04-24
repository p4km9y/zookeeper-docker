.DEFAULT_GOAL := build
.PHONY: build deploy

VER := $(shell sed -n -e 's/^.\+ZK_VERSION\s\+\(.\+\)/\1/p' < Dockerfile)

build:
	docker build -t p4km9y/zookeeper -t p4km9y/zookeeper:${VER} .

deploy: build
	docker login
	docker push p4km9y/zookeeper:${VER}
