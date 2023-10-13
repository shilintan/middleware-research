#!/bin/bash
set -e

if [ ! "${CI_COMMIT_REF_NAME}" = "main" ] && [ ! "${CI_COMMIT_REF_NAME}" = "test" ]; then
  echo "不是约定的流水线不需要运行ci"
  exit 1
fi

is_need_build_image_filename="is_need_build_image"
CHECK_MD5_FILE=check.md5
ROOT_PATH=$(pwd)
local_cache_path="/build/cache/data/repo_gen/$CI_PROJECT_NAME/${CI_COMMIT_REF_NAME}-${CI_COMMIT_TAG}"
mvn_args="--settings /build/cache/config/maven/settings.xml  --batch-mode"
if [ ! -f /etc/os-release ]; then
  local_cache_path="/d/tmp/s2b2b2c-ui"
  mvn_args=" "
fi


function checkdirmd5(){
    for file in `ls -a $1`
    do
        if [ "$file" == . ] || [ "$file" == .. ] || [ "$file" == ".git" ] || [ "$file" == ".idea" ] || [[ "$file" == *".iml"* ]] || [[ "$1/$file" == *"/target/"* ]] || [[ "$file" == *"check.md5"* ]] || [[ "$file" == *"node_modules"* ]] || [[ "$file" == *"dist"* ]]
        then
          continue
        fi
        if [ -d "$1/$file" ]
        then
            checkdirmd5 "$1/$file" "$2"
        else
            md5sum "$1/$file" | sed "s#$ROOT_PATH/##" >> "$2"
        fi
    done
}


# build deploy
echo "build deploy"
cd $ROOT_PATH
for project_core_file in `find . -type f -name '.gitlab-ci.type'|awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  project_path=`dirname $project_core_file`
  cd $project_path
  if [ `cat ".gitlab-ci.type"` == 'deploy' ]; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> current project is ${project_path} <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    mkdir -p "${local_cache_path}/${project_path}"
    test -e "${CHECK_MD5_FILE}-files" && rm "${CHECK_MD5_FILE}-files"
    test -e "${CHECK_MD5_FILE}-new" && rm "${CHECK_MD5_FILE}-new"
    test -e "${CHECK_MD5_FILE}" && rm "${CHECK_MD5_FILE}"
    checkdirmd5 "." "${CHECK_MD5_FILE}-files"
    md5sum "${CHECK_MD5_FILE}-files" | sed "s#$ROOT_PATH/##" >> "${CHECK_MD5_FILE}-new"
    test -e "./${CHECK_MD5_FILE}" && /bin/rm -rf "./${CHECK_MD5_FILE}"
    test -e "${local_cache_path}/${project_path}/${CHECK_MD5_FILE}" && /bin/cp -rf "${local_cache_path}/${project_path}/${CHECK_MD5_FILE}" "./${CHECK_MD5_FILE}"
    if [ ! -f "$CHECK_MD5_FILE" ] || ! md5sum -c "$CHECK_MD5_FILE"; then
      mkdir -p "${local_cache_path}/${project_path}/node_modules"
      echo "loading node_modules from cache"
      /bin/cp -aurf -R "${local_cache_path}/${project_path}/node_modules" ./

      yarn config set registry https://registry.npm.taobao.org
      yarn config set disturl https://npm.taobao.org/dist
      yarn config set sass_binary_site http://cdn.npm.taobao.org/dist/node-sass
      yarn install

      yarn build
      ls -alh dist/

      rm -rf           "${local_cache_path}/${project_path}/dist"
      echo "store node_modules to cache"
      /bin/cp -aurf -R node_modules "${local_cache_path}/${project_path}"
      /bin/cp -rf   -R dist         "${local_cache_path}/${project_path}"


      /bin/cp -rf "./${CHECK_MD5_FILE}-new" "${local_cache_path}/${project_path}/${CHECK_MD5_FILE}"
      echo "yes" > "${local_cache_path}/${project_path}/${is_need_build_image_filename}"
    fi
  fi
done