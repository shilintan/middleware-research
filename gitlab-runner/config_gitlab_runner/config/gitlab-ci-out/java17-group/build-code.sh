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
#local_cache_path="/d/tmp/s2b2b2c-service"
#mvn_args=" "


function checkdirmd5(){
    for file in `ls -a $1`
    do
        if [ "$file" == . ] || [ "$file" == .. ] || [ "$file" == ".git" ] || [ "$file" == ".idea" ] || [[ "$file" == *".iml"* ]] || [[ "$1/$file" == *"/target/"* ]] || [[ "$file" == *"check.md5"* ]]
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
mvn_install_list=()

# build group
echo "build group"
cd $ROOT_PATH
for pom_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  pom_dir_path=`dirname $pom_file`
  cd $pom_dir_path
  if [ `cat ".gitlab-ci.type"` == 'group' ]; then
    echo "current project is ${pom_dir_path}"
    mkdir -p "${local_cache_path}/${pom_dir_path}"
    test -e "./${CHECK_MD5_FILE}" && /bin/rm -rf "./${CHECK_MD5_FILE}"
    test -e "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" && /bin/cp -rf "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" "./${CHECK_MD5_FILE}"
    if [ ! -f "$CHECK_MD5_FILE" ] || ! md5sum -c "$CHECK_MD5_FILE"; then
      is_parent_maven_install="no"
      for element in ${mvn_install_list[@]}
      do
        if [[ "$pom_dir_path"  == *"$element"* ]]; then
          is_parent_maven_install="yes"
          break
        fi
      done
      if [ "$is_parent_maven_install" == "no" ]; then
#        echo "mvn install -DskipTests $mvn_args"
        mvn install -DskipTests $mvn_args
        mvn_install_list+=("$pom_dir_path")
      fi
      md5sum "pom.xml" | sed "s#$ROOT_PATH/##" > "$CHECK_MD5_FILE"
      /bin/cp -rf "./${CHECK_MD5_FILE}" "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}"
    fi
  fi
done

# build dependency
echo "build dependency"
cd $ROOT_PATH
for pom_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  pom_dir_path=`dirname $pom_file`
#  echo "pom_dir_path is $pom_dir_path"
  cd $pom_dir_path
  if [ `cat ".gitlab-ci.type"` == 'dependency' ]; then
    echo "current project is ${pom_dir_path}"
    mkdir -p "${local_cache_path}/${pom_dir_path}"
    test -e "${CHECK_MD5_FILE}-files" && rm "${CHECK_MD5_FILE}-files"
    test -e "${CHECK_MD5_FILE}-new" && rm "${CHECK_MD5_FILE}-new"
    test -e "${CHECK_MD5_FILE}" && rm "${CHECK_MD5_FILE}"
    checkdirmd5 "." "${CHECK_MD5_FILE}-files"
    md5sum "${CHECK_MD5_FILE}-files" | sed "s#$ROOT_PATH/##" >> "${CHECK_MD5_FILE}-new"
    test -e "./${CHECK_MD5_FILE}" && /bin/rm -rf "./${CHECK_MD5_FILE}"
    test -e "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" && /bin/cp -rf "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" "./${CHECK_MD5_FILE}"
    if [ ! -f "$CHECK_MD5_FILE" ] || ! md5sum -c "$CHECK_MD5_FILE"; then
      is_parent_maven_install="no"
      for element in ${mvn_install_list[@]}
      do
        if [[ "$pom_dir_path"  == *"$element"* ]]; then
          is_parent_maven_install="yes"
          break
        fi
      done
      if [ "$is_parent_maven_install" == "no" ]; then
#        echo "mvn install -DskipTests $mvn_args"
        mvn install -DskipTests $mvn_args
        mvn_install_list+=("$pom_dir_path")
      fi
      /bin/cp -rf "./${CHECK_MD5_FILE}-new" "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}"
    fi
  fi
done

# build dependency-out
echo "build dependency-out"
cd $ROOT_PATH
for pom_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  pom_dir_path=`dirname $pom_file`
#  echo "pom_dir_path is $pom_dir_path"
  cd $pom_dir_path
  if [ `cat ".gitlab-ci.type"` == 'dependency-out' ]; then
    echo "current project is ${pom_dir_path}"
    mkdir -p "${local_cache_path}/${pom_dir_path}"
    test -e "${CHECK_MD5_FILE}-files" && rm "${CHECK_MD5_FILE}-files"
    test -e "${CHECK_MD5_FILE}-new" && rm "${CHECK_MD5_FILE}-new"
    test -e "${CHECK_MD5_FILE}" && rm "${CHECK_MD5_FILE}"
    checkdirmd5 "." "${CHECK_MD5_FILE}-files"
    md5sum "${CHECK_MD5_FILE}-files" | sed "s#$ROOT_PATH/##" >> "${CHECK_MD5_FILE}-new"
    test -e "./${CHECK_MD5_FILE}" && /bin/rm -rf "./${CHECK_MD5_FILE}"
    test -e "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" && /bin/cp -rf "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" "./${CHECK_MD5_FILE}"
    if [ ! -f "$CHECK_MD5_FILE" ] || ! md5sum -c "$CHECK_MD5_FILE"; then
      is_parent_maven_install="no"
      for element in ${mvn_install_list[@]}
      do
        if [[ "$pom_dir_path"  == *"$element"* ]]; then
          is_parent_maven_install="yes"
          break
        fi
      done
      if [ "$is_parent_maven_install" == "no" ]; then
#        echo "mvn install -DskipTests $mvn_args"
        mvn install -DskipTests $mvn_args
        mvn_install_list+=("$pom_dir_path")
      fi
      /bin/cp -rf "./${CHECK_MD5_FILE}-new" "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}"
    fi
  fi
done

# build group-deploy
echo "build group-deploy"
cd $ROOT_PATH
for pom_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  pom_dir_path=`dirname $pom_file`
  cd $pom_dir_path
  if [ `cat ".gitlab-ci.type"` == 'group-deploy' ]; then
    echo "current project is ${pom_dir_path}"
    mkdir -p "${local_cache_path}/${pom_dir_path}"
    test -e "./${CHECK_MD5_FILE}" && /bin/rm -rf "./${CHECK_MD5_FILE}"
    test -e "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" && /bin/cp -rf "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" "./${CHECK_MD5_FILE}"
    if [ ! -f "$CHECK_MD5_FILE" ] || ! md5sum -c "$CHECK_MD5_FILE"; then
      is_parent_maven_install="no"
      for element in ${mvn_install_list[@]}
      do
        if [[ "$pom_dir_path"  == *"$element"* ]]; then
          is_parent_maven_install="yes"
          break
        fi
      done
      echo "$pom_dir_path     $is_parent_maven_install"
      if [ "$is_parent_maven_install" == "no" ]; then
#        echo "mvn install -DskipTests $mvn_args"
        mvn install -DskipTests $mvn_args
        mvn_install_list+=("$pom_dir_path")
      fi
      md5sum "pom.xml" | sed "s#$ROOT_PATH/##" > "$CHECK_MD5_FILE"
      /bin/cp -rf "./${CHECK_MD5_FILE}" "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}"
    fi
  fi
done

# build deploy
echo "build deploy"
cd $ROOT_PATH
for pom_file in `find . -type f -name '.gitlab-ci.type' |awk '{print length(), $0 | "sort -n" }'|awk '{print $2}'`
do
  cd $ROOT_PATH
  pom_dir_path=`dirname $pom_file`
  cd $pom_dir_path
  if [ `cat ".gitlab-ci.type"` == 'deploy' ]; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> current project is ${pom_dir_path} <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    mkdir -p "${local_cache_path}/${pom_dir_path}"
    test -e "${CHECK_MD5_FILE}-files" && rm "${CHECK_MD5_FILE}-files"
    test -e "${CHECK_MD5_FILE}-new" && rm "${CHECK_MD5_FILE}-new"
    test -e "${CHECK_MD5_FILE}" && rm "${CHECK_MD5_FILE}"
    checkdirmd5 "." "${CHECK_MD5_FILE}-files"
    md5sum "${CHECK_MD5_FILE}-files" | sed "s#$ROOT_PATH/##" >> "${CHECK_MD5_FILE}-new"
    test -e "./${CHECK_MD5_FILE}" && /bin/rm -rf "./${CHECK_MD5_FILE}"
    test -e "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" && /bin/cp -rf "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}" "./${CHECK_MD5_FILE}"
    if [ ! -f "$CHECK_MD5_FILE" ] || ! md5sum -c "$CHECK_MD5_FILE"; then
      is_parent_maven_install="no"
      for element in ${mvn_install_list[@]}
      do
        if [[ "$pom_dir_path"  == *"$element"* ]]; then
          is_parent_maven_install="yes"
          break
        fi
      done
      if [ "$is_parent_maven_install" == "no" ]; then
#        echo "mvn install -DskipTests $mvn_args"
        mvn package -DskipTests $mvn_args
        mvn_install_list+=("$pom_dir_path")
      fi
      /bin/cp -rf "./${CHECK_MD5_FILE}-new" "${local_cache_path}/${pom_dir_path}/${CHECK_MD5_FILE}"
      echo "yes" > "${local_cache_path}/${pom_dir_path}/${is_need_build_image_filename}"
      /bin/rm -rf target/*-sources.jar
      /bin/cp -rf target/*.jar "${local_cache_path}/${pom_dir_path}/"
    fi
  fi
done