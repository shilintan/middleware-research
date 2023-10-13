#!/bin/bash
set -e

if [ ! "${CI_COMMIT_REF_NAME}" = "main" ] && [ ! "${CI_COMMIT_REF_NAME}" = "test" ]; then
  echo "不是约定的流水线不需要运行ci"
  exit 1
fi

is_need_deploy_image_filename="is_need_deploy_image"
is_need_wait_deploy_image_filename="is_need_wait_deploy_image"
ROOT_PATH=$(pwd)
local_cache_path="/build/cache/data/repo_gen/$CI_PROJECT_NAME/${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"
#local_cache_path="/d/tmp/s2b2b2c-service"


if [  "${CI_COMMIT_REF_NAME}" = "main" ]; then
    namespace=prod
    env_path=/build/cache/config/auth-yidongyun
    my_registry=container.your-domain-name.com
    template_ingress_domain_prefix=your-domain-name.com
    template_rc_init_count=1

    template_app_resources_requests_cpu="500m"
    template_app_resources_requests_memory="1Gi"
    template_app_resources_requests_ephemeral_storage="1Gi"
    template_app_resources_limits_cpu="4000m"
    template_app_resources_limits_memory="8Gi"
    template_app_resources_limits_ephemeral_storage="1Gi"

    template_configmap_java_opts="-Xms2g -Xmx4g"
elif [  "${CI_COMMIT_REF_NAME}" = "test" ]; then
    namespace=test
    env_path=/build/cache/config/auth-local
    my_registry=container.local.your-domain-name.com
    template_ingress_domain_prefix=local.your-domain-name.com
    template_rc_init_count=1

    template_app_resources_requests_cpu="10m"
    template_app_resources_requests_memory="1Gi"
    template_app_resources_requests_ephemeral_storage="100Mi"
    template_app_resources_limits_cpu="4000m"
    template_app_resources_limits_memory="8Gi"
    template_app_resources_limits_ephemeral_storage="1Gi"

    template_configmap_java_opts="-Xms512m -Xmx1024m"
else
  exit 1
fi

echo $namespace $my_registry $env_path

# deploy image
echo "deploy image"
cd $ROOT_PATH
for pom_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  pom_dir_path=`dirname $pom_file`
  cd $pom_dir_path
  if [ `cat ".gitlab-ci.type"` == 'deploy' ]; then
    if [ -f "${local_cache_path}/${pom_dir_path}/${is_need_deploy_image_filename}" ]; then
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> deploy image for $pom_dir_path <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        server_name=`cat .gitlab-ci.appname`

        image_id="${my_registry}"/repo/"${server_name}":"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}-${CI_PIPELINE_ID}"
        echo $namespace $server_name   $image_id
        /bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/k8s.yaml               k8s.yaml
        /bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/k8s-configmap.yaml     k8s-configmap.yaml
        sed -i "s/template_namespace_name/${namespace}/g" k8s.yaml
        sed -i "s/template_sever_name/${server_name}/g"   k8s.yaml
        sed -i "s/template_ingress_domain_prefix/${template_ingress_domain_prefix}/g"   k8s.yaml
        sed -i "s#template_sever_image#${image_id}#g"     k8s.yaml
        sed -i "s#template_rc_init_count#${template_rc_init_count}#g" k8s.yaml
        sed -i "s#template_app_resources_requests_cpu#${template_app_resources_requests_cpu}#g" k8s.yaml
        sed -i "s#template_app_resources_requests_memory#${template_app_resources_requests_memory}#g" k8s.yaml
        sed -i "s#template_app_resources_requests_ephemeral_storage#${template_app_resources_requests_ephemeral_storage}#g" k8s.yaml
        sed -i "s#template_app_resources_limits_cpu#${template_app_resources_limits_cpu}#g" k8s.yaml
        sed -i "s#template_app_resources_limits_memory#${template_app_resources_limits_memory}#g" k8s.yaml
        sed -i "s#template_app_resources_limits_ephemeral_storage#${template_app_resources_limits_ephemeral_storage}#g" k8s.yaml
        cat k8s.yaml
        sed -i "s/template_namespace_name/${namespace}/g" k8s-configmap.yaml
        sed -i "s/template_sever_name/${server_name}/g"   k8s-configmap.yaml
        sed -i "s/template_configmap_java_opts/${template_configmap_java_opts}/g"   k8s-configmap.yaml
        cat k8s-configmap.yaml


        repo_gen_path=/build/cache/data/k8s_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"/${pom_dir_path}/
        mkdir -p $repo_gen_path
        /bin/cp -rf k8s.yaml $repo_gen_path/k8s.yaml
        /bin/cp -rf k8s-configmap.yaml $repo_gen_path/k8s-configmap.yaml
        kubectl config set-credentials gitlab-runner --token=`cat "${env_path}"/k8s/token`
        kubectl config set-cluster mycluster --insecure-skip-tls-verify=true --server=`cat "${env_path}"/k8s/server_uri`
        kubectl config set-context mycontext --cluster=mycluster --user=gitlab-runner
        kubectl config use-context mycontext
        kubectl -n "$namespace" get pods -o wide|grep "$server_name" || echo
        kubectl create -f k8s-configmap.yaml || echo
        kubectl apply -f k8s.yaml || echo
        kubectl -n "$namespace" set image deployment/"$server_name" app="$image_id"

        deploy_image_list+=("$server_name")

        /bin/rm -rf "${local_cache_path}/${pom_dir_path}/${is_need_deploy_image_filename}"

        echo "yes" > "${local_cache_path}/${pom_dir_path}/${is_need_wait_deploy_image_filename}"
    fi
  fi
done

# wait deploy image
echo "wait deploy image"
sleep 10
cd $ROOT_PATH
for pom_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  pom_dir_path=`dirname $pom_file`
  cd $pom_dir_path
  if [ `cat ".gitlab-ci.type"` == 'deploy' ]; then
    if [ -f "${local_cache_path}/${pom_dir_path}/${is_need_wait_deploy_image_filename}" ]; then
        server_name=`cat .gitlab-ci.appname`
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> wait deploy image for $pom_dir_path <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        kubectl -n "$namespace" wait pods -l app="${server_name}" --for=condition=Ready=true --timeout=300s
        kubectl -n "$namespace" get pods -o wide|grep "$server_name"
        echo "服务访问地址:"
        kubectl -n "$namespace" get ingress -o wide|grep "$server_name" || echo

        /bin/rm -rf "${local_cache_path}/${project_path}/${is_need_wait_deploy_image_filename}"
    fi
  fi
done