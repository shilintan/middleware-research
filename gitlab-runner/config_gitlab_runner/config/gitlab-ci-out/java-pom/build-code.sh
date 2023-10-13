#!/bin/bash
set -e

if [ "${CI_COMMIT_REF_NAME}" = "main" ]; then
  export test=test
elif [ "${CI_COMMIT_REF_NAME}" = "test" ]; then
  export test=test
else
  echo "不是约定的流水线不需要运行ci"
  exit 1
fi

echo "Asia/Shanghai" > /etc/timezone
mvn install -DskipTests --settings /build/cache/config/maven/settings.xml --batch-mode