#!/bin/bash

xcodebuild -target DeafShark.xcodeproj -scheme DeafShark -configuration Release CONFIGURATION_BUILD_DIR='build'
echo -e "\nExecutable located at build/DeafShark"
