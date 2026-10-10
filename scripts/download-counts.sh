#!/bin/bash
set -euo pipefail
# GitHub's aggregate release-asset counts; exclude checksum files.
gh api --paginate repos/shawonibnkamal/doclin-macos/releases --jq '.[] | .tag_name as $tag | .assets[] | select(.name | endswith(".zip")) | [$tag, .name, .download_count] | @tsv'
