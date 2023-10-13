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

if [  "${CI_COMMIT_REF_NAME}" = "main" ]; then
    export namespace=prod
    export my_registry=container.your-domain-name.com
    export env_path=/build/cache/config/auth-yidongyun
elif [  "${CI_COMMIT_REF_NAME}" = "test" ]; then
    export namespace=test
    export my_registry=container.local.your-domain-name.com
    export env_path=/build/cache/config/auth-local
else
  exit 1
fi

echo $namespace $my_registry $env_path

export server_name=$CI_PROJECT_NAME
/bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/default.conf     default.conf
/bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/Dockerfile       Dockerfile
ls -alh *
export image_id="${my_registry}"/repo/"${CI_PROJECT_NAME}":"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}-${CI_PIPELINE_ID}"
buildah --registries-conf /build/cache/config/container/registries.conf build --no-cache --format docker -t $image_id .
buildah login -u username --password-stdin < "${env_path}"/container/password "${my_registry}"
buildah push     $image_id
buildah rmi      $image_id