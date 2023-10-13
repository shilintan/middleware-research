#!/bin/bash
set -e

if [ ! "${CI_COMMIT_REF_NAME}" = "main" ] && [ ! "${CI_COMMIT_REF_NAME}" = "test" ]; then
  echo "不是约定的流水线不需要运行ci"
  exit 1
fi

if [  "${CI_COMMIT_REF_NAME}" = "main" ]; then
    namespace=prod
    my_registry=container.your-domain-name.com
    env_path=/build/cache/config/auth-yidongyun
elif [  "${CI_COMMIT_REF_NAME}" = "test" ]; then
    namespace=test
    my_registry=container.local.your-domain-name.com
    env_path=/build/cache/config/auth-local
else
  exit 1
fi

echo $namespace $my_registry $env_path

server_name=`cat .gitlab-ci.appname`
/bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/default.conf     default.conf
/bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/Dockerfile       Dockerfile
ls -alh ./
ls -alh unpackage/dist/build/h5
image_id="${my_registry}"/repo/"${server_name}":"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}-${CI_PIPELINE_ID}"
buildah --registries-conf /build/cache/config/container/registries.conf build --no-cache --format docker -t $image_id .
buildah login -u username --password-stdin < "${env_path}"/container/password "${my_registry}"
buildah push     $image_id
buildah rmi      $image_id