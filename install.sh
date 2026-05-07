#!/bin/bash
set -euo pipefail

swift build -c release
cp -f "$(swift build -c release --show-bin-path)/VersionIcon" Bin/VersionIcon
