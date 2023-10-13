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

server_name=$CI_PROJECT_NAME
/bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/Dockerfile     Dockerfile
sed -i "s/template_sever_name/${server_name}/g" Dockerfile
/bin/cp -rf /build/cache/data/repo_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"/*.jar app.jar
/bin/cp -rf /build/cache/config/jmx_exporter/jmx_exporter_config.yaml                jmx_exporter_config.yaml
/bin/cp -rf /build/cache/data/jmx_exporter/jmx_prometheus_javaagent-0.20.0.jar       jmx_prometheus_javaagent.jar
/bin/cp -rf /build/cache/data/otel/opentelemetry-javaagent.jar                       opentelemetry-javaagent.jar
ls -alh app.jar
image_id="${my_registry}"/repo/"${CI_PROJECT_NAME}":"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}-${CI_PIPELINE_ID}"
buildah --registries-conf /build/cache/config/container/registries.conf build --no-cache --format docker -t $image_id .
buildah login -u username --password-stdin < "${env_path}"/container/password "${my_registry}"
buildah push     $image_id
buildah rmi      $image_id