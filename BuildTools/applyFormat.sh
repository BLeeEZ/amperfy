#!/bin/sh

# Get the current working directory
cwd=$(pwd)

target_dir="BuildTools"
swiftformat_exec="./.build/release/swiftformat"

# Check if the current directory ends with "BuildTools"
if [[ "$cwd" =~ $target_dir$ ]]; then
  :
else
  cd "$target_dir"
fi

# Check if SwiftFormat has already been build
if [ ! -f "$swiftformat_exec" ]; then
  echo "SwiftFormat not build yet: start build"
  SDKROOT=(xcrun --sdk macosx --show-sdk-path)
  swift run -c release swiftformat "$SRCROOT"
fi

"$swiftformat_exec" ..