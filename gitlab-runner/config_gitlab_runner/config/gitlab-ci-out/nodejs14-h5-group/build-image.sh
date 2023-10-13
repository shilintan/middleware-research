#!/bin/bash
set -e

if [ ! "${CI_COMMIT_REF_NAME}" = "main" ] && [ ! "${CI_COMMIT_REF_NAME}" = "test" ]; then
  echo "不是约定的流水线不需要运行ci"
  exit 1
fi

is_need_build_image_filename="is_need_build_image"
is_need_deploy_image_filename="is_need_deploy_image"
ROOT_PATH=$(pwd)
local_cache_path="/build/cache/data/repo_gen/$CI_PROJECT_NAME/${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"
if [ ! -f /etc/os-release ]; then
  local_cache_path="/d/tmp/s2b2b2c-ui"
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

# build image
echo "build image"
cd $ROOT_PATH
for project_core_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  project_path=`dirname $project_core_file`
  cd $project_path
  if [ `cat ".gitlab-ci.type"` == 'deploy' ]; then
    if [ -f "${local_cache_path}/${project_path}/${is_need_build_image_filename}" ]; then
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> build image for $project_path <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        server_name=`cat .gitlab-ci.appname`

        rm -rf Dockerfile
        /bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/default.conf   default.conf
        /bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/Dockerfile     Dockerfile
        ls -alh "${local_cache_path}/${project_path}/dist"
        /bin/cp -rf "${local_cache_path}/${project_path}/dist" ./
        ls -alh dist
        image_id="${my_registry}"/repo/"${server_name}":"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}-${CI_PIPELINE_ID}"
        buildah --registries-conf /build/cache/config/container/registries.conf build --no-cache --format docker -t $image_id .
        buildah login -u username --password-stdin < "${env_path}"/container/password "${my_registry}"
        buildah push     $image_id
        buildah rmi      $image_id

        /bin/rm -rf "${local_cache_path}/${project_path}/${is_need_build_image_filename}"
        /bin/rm -rf "${local_cache_path}/${project_path}/dist"

        echo "yes" > "${local_cache_path}/${project_path}/${is_need_deploy_image_filename}"
    fi
  fi
done