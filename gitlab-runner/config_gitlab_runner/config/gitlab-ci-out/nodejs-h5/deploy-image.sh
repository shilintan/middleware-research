#!/bin/bash
set -e

if [ ! "${CI_COMMIT_REF_NAME}" = "main" ] && [ ! "${CI_COMMIT_REF_NAME}" = "test" ]; then
  echo "不是约定的流水线不需要运行ci"
  exit 1
fi

if [  "${CI_COMMIT_REF_NAME}" = "main" ]; then
    namespace=prod
    env_path=/build/cache/config/auth-yidongyun
    my_registry=container.your-domain-name.com
    template_ingress_domain_prefix=your-domain-name.com
    template_rc_init_count=3
elif [  "${CI_COMMIT_REF_NAME}" = "test" ]; then
    namespace=test
    env_path=/build/cache/config/auth-local
    my_registry=container.local.your-domain-name.com
    template_ingress_domain_prefix=local.your-domain-name.com
    template_rc_init_count=1
else
  exit 1
fi

echo $namespace $my_registry $env_path

server_name=$CI_PROJECT_NAME
image_id="${my_registry}"/repo/"${CI_PROJECT_NAME}":"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}-${CI_PIPELINE_ID}"
echo $namespace $server_name   $image_id
/bin/cp -rf /build/cache/config/gitlab-ci-out/"${ci_type}"/k8s.yaml               k8s.yaml

sed -i "s/template_namespace_name/${namespace}/g" k8s.yaml
sed -i "s/template_sever_name/${server_name}/g"   k8s.yaml
sed -i "s/template_ingress_domain_prefix/${template_ingress_domain_prefix}/g"   k8s.yaml
sed -i "s#template_sever_image#${image_id}#g"     k8s.yaml
sed -i "s#template_rc_init_count#${template_rc_init_count}#g" k8s.yaml
cat k8s.yaml
#sed -i "s/template_namespace_name/${namespace}/g" k8s-configmap.yaml
#sed -i "s/template_sever_name/${server_name}/g"   k8s-configmap.yaml
#cat k8s-configmap.yaml
mkdir -p /build/cache/data/k8s_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}/"
/bin/cp -rf k8s.yaml /build/cache/data/k8s_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"/k8s.yaml
#/bin/cp -rf k8s-configmap.yaml /build/cache/data/k8s_gen/$CI_PROJECT_NAME/"${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"/k8s-configmap.yaml
kubectl config set-credentials gitlab-runner --token=`cat "${env_path}"/k8s/token`
kubectl config set-cluster mycluster --insecure-skip-tls-verify=true --server=`cat "${env_path}"/k8s/server_uri`
kubectl config set-context mycontext --cluster=mycluster --user=gitlab-runner
kubectl config use-context mycontext
kubectl -n "$namespace" get pods -o wide|grep "$server_name" || echo
#kubectl create -f k8s-configmap.yaml || echo
kubectl create -f k8s.yaml || echo
kubectl -n "$namespace" set image deployment/"$server_name" app="$image_id"
kubectl -n "$namespace" wait pods -l app="${server_name}" --for=condition=Ready=true --timeout=600s
sleep 10
kubectl -n "$namespace" get pods -o wide|grep "$server_name"

echo "服务访问地址:"
kubectl -n "$namespace" get ingress -o wide|grep "$server_name" || echo

# kubectl -n prod scale deployment redpack --replicas=6