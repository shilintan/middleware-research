#!/bin/bash
set -e

if [ ! "${CI_COMMIT_REF_NAME}" = "main" ] && [ ! "${CI_COMMIT_REF_NAME}" = "test" ]; then
  echo "不是约定的流水线不需要运行ci"
  exit 1
fi

#mkdir -p /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}/"
mkdir -p /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}/node_modules"
/bin/cp -rf -R /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}/node_modules" ./

echo "Asia/Shanghai" > /etc/timezone

npm config set registry https://registry.npmmirror.com && npm ci --sass_binary_site=https://registry.npmmirror.com/node-sass
npm run build

ls -alh dist/

rm -rf /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}/dist"
/bin/cp -rf -R node_modules /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"
/bin/cp -rf -R dist         /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"