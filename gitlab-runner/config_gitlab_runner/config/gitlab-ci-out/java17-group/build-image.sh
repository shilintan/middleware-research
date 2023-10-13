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
#local_cache_path="/d/tmp/s2b2b2c-service"


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


# build image
echo "build image"
cd $ROOT_PATH
for pom_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  pom_dir_path=`dirname $pom_file`
  cd $pom_dir_path
  if [ ! -f ".gitlab-ci.type" ]; then
    continue
  fi
  if [ `cat ".gitlab-ci.type"` == 'deploy' ]; then
    if [ -f "${local_cache_path}/${pom_dir_path}/${is_need_build_image_filename}" ]; then
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> build image for $pom_dir_path <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        server_name=`cat .gitlab-ci.appname`
        /bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/Dockerfile     Dockerfile
        sed -i "s/template_sever_name/${server_name}/g" Dockerfile
        ls -alh /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"/${pom_dir_path}/
        /bin/cp -rf /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"/${pom_dir_path}/*.jar app.jar
        /bin/cp -rf /build/cache/config/jmx_exporter/jmx_exporter_config.yaml                jmx_exporter_config.yaml
        /bin/cp -rf /build/cache/data/jmx_exporter/jmx_prometheus_javaagent-0.20.0.jar       jmx_prometheus_javaagent.jar
        /bin/cp -rf /build/cache/data/otel/opentelemetry-javaagent.jar                       opentelemetry-javaagent.jar
        ls -alh app.jar
        export image_id="${my_registry}"/repo/"${server_name}":"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}-${CI_PIPELINE_ID}"
        buildah --registries-conf /build/cache/config/container/registries.conf build --no-cache --format docker -t $image_id .
        buildah login -u username --password-stdin < "${env_path}"/container/password "${my_registry}"
        buildah push     $image_id
        buildah rmi      $image_id

        /bin/rm -rf "${local_cache_path}/${pom_dir_path}/${is_need_build_image_filename}"
        /bin/rm -rf /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"/${pom_dir_path}/*.jar

        echo "yes" > "${local_cache_path}/${pom_dir_path}/${is_need_deploy_image_filename}"
    fi
  fi
done