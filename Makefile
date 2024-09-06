TAG := $(shell git tag --sort=committerdate | tail -1)

lint:
	docker run --rm \
		-v "$(shell pwd):/app" \
		-e UID="${UID}" \
		--pull=always \
		behretv/lint:latest

build:
	docker build --pull \
   --build-arg BASE_IMAGE=dustynv/ros:iron-desktop-l4t-r35.4.1 \
   --build-arg CATKIN_WS=/root/catkin_ws \
   --build-arg ROS_DISTRO=iron \
   --build-arg UBUNTU_VERSION=20.04 \
   --file Dockerfile \
   --tag behretv/rtab-map-dependencies:${TAG} \
		 .

