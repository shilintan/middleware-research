#!/bin/bash
set -e

if [ ! "${CI_COMMIT_REF_NAME}" = "main" ] && [ ! "${CI_COMMIT_REF_NAME}" = "test" ]; then
  echo "不是约定的流水线不需要运行ci"
  exit 1
fi

echo "Asia/Shanghai" > /etc/timezone
rm -rf env/.env
mvn clean package -DskipTests --settings /build/cache/config/maven/settings.xml --batch-mode
ls -alh target/
mkdir -p /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}/"
rm -rf /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}/*"
/bin/cp -rf target/*.jar /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}/"