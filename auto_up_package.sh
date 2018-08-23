#!/bin/bash

######################################
#functions: up local package to update ftp
#author: luxson
#date: 2016/08/17
######################################

# 上传在线升级包到ftp
function auto_up_package_to_ftp()
{
  # 上传官网包
  official_file="$(echo "${official_file}" | tr ',' ' ')"
  if [ "${upload_recovery_website}" == "true" ] && [ -f "${local_official_path}${official_file}" ];then
    echo "正在上传${official_file}官网升级包，请稍后..."
    ${connect_ftp} <<EOF
    cd ${official_ftp_path}
    lcd ${local_official_path}
    put ${official_file}
    bye
EOF
    return 0
  fi
  update_file="$(echo "${update_file}" | tr ',' ' ')"
  recovery_file="$(echo "${recovery_file}" | tr ',' ' ')"
  no_exist_file_list=
  # 上传增量升级包
  if [ "${only_upload_recovery}" != "true" ];then
    for file in ${update_file};do
      if [ ! -f "${local_update_path}${file}" ];then
        no_exist_file_list="${no_exist_file_list} ${file}"
      fi
    done
    for file in ${update_file}
    do
      if [ -f "${local_update_path}${file}" ];then
        echo "正在上传${file}升级包，请稍后..."
        ${connect_ftp} <<EOF
        cd ${update_ftp_path}
        lcd ${local_update_path}
        put ${file}
        bye
EOF
      fi
    done
  fi
  # 上传recovery包
  if [ "${no_upload_recovery}" != "true" ];then
    if [ ! -f "${local_recovery_path}${recovery_file}" ];then
      no_exist_file_list="${no_exist_file_list} ${recovery_file}"
    else
      echo "正在上传recovery包${recovery_file}，请稍后..."
      ${connect_ftp} <<EOF
      cd ${recovery_ftp_path}
      lcd ${local_recovery_path}
      put ${recovery_file}
      bye
EOF
    fi
  fi

  if [ -n "$(echo "${no_exist_file_list}")" ];then
    no_exist_file_list="$(echo ${no_exist_file_list})"
    echo -e "\n香港ftp缺少升级包(${no_exist_file_list}),请先上传!" && exit 1
  fi
}

# 删除本地临时文件
function remove_local_file()
{
  for file in ${update_file};do
    if [ -f "${local_update_path}${file}" ];then
      rm -rf "${local_update_path}${file}"
    fi
  done
  if [ -f "${local_recovery_path}${recovery_file}" ];then
    rm -rf "${local_recovery_path}${recovery_file}"
  fi
}

# ftp代理服务器修改etc文件
function modify_etc_file()
{
  if [ -n "${proxy_ip}" ] && [ -n "${proxy_user}" ] && [ -n "${proxy_pass}" ] && [ -z "`cat "${etc_file}" | grep "${proxy_ip}"`" ];then
    first_nu="`echo "${proxy_ip}" | awk -F '.' '{print $1}'`"
    local_modify="`cat /etc/tsocks.conf | grep ^"local =" | grep 255.0.0 | awk -F '=' '{print $2}'`"
    server_modify="`cat /etc/tsocks.conf | grep ^"server =" | awk -F '=' '{print $2}'`"
    proxy_user_modify="`cat /etc/tsocks.conf | grep ^"default_user =" | awk -F '=' '{print $2}'`"
    proxy_pass_modify="`cat /etc/tsocks.conf | grep ^"default_pass =" | awk -F '=' '{print $2}'`"
    current_etc_path="/data/www/upgrade/project/${remote_temp_etc_path}"
    mkdir -p ${current_etc_path}/${proxy_ip}
    cp /etc/tsocks.conf ${current_etc_path}/${proxy_ip}/tsocks.conf
    sed -i "s#${local_modify}# ${first_nu}.0.0.0/255.0.0.0#g" ${current_etc_path}/${proxy_ip}/tsocks.conf
    sed -i "s#${server_modify}# ${proxy_ip}#g" ${current_etc_path}/${proxy_ip}/tsocks.conf
    sed -i "s#${proxy_user_modify}# ${proxy_user}#g" ${current_etc_path}/${proxy_ip}/tsocks.conf
    sed -i "s#${proxy_pass_modify}# ${proxy_pass}#g" ${current_etc_path}/${proxy_ip}/tsocks.conf
    cp ${current_etc_path}/${proxy_ip}/tsocks.conf /etc/tsocks.conf
    rm -rf "${current_etc_path}"
  fi
}

# 外销传升级包入口
function overseas_upload()
{
  update_ftp_path="/upload/UpdateFiles/"
  recovery_ftp_path="/recovery/recoveryFiles/"
  official_ftp_path="/official/officialFiles/"
  local_update_path="/data/www/upgrade/upload/UpdateFiles/"
  local_recovery_path="/data/www/upgrade/recovery/recoveryFiles/"
  local_official_path="/data/www/upgrade/official/officialFiles/"
  etc_file="/etc/tsocks.conf"
  if [ ! -d "${local_update_path}" ];then
    echo "ERROR: 本地路径${local_update_path}不存在，退出自动上传升级包。" && usage && exit 1
  fi
  while [ "1" -eq "1" ];do
    if [ -n "`ps aux | grep 'lftp -u' | grep -v 'grep'`" ];then
      echo "有项目正在传升级包，请稍等60s..."
      sleep 60
    else
      break
    fi
  done
  if [ "${transfor_ftp_host}" == "47.88.226.3" ];then
    user=exupgradenew
    pass=DCyDsybhLLguk7Yp
    echo "${project_name}项目升级包正在从香港ftp中转到新加坡ftp..."
    connect_ftp="lftp -u ${user},${pass} ftp://${ftp_host}:21"
  else
    echo "error: unknow ftp host:${transfor_ftp_host}" && exit 1
  fi

  # 修改ftp代理服务器etc文件
  #modify_etc_file

  # 上传升级包
  auto_up_package_to_ftp

  # 删除本地临时文件
  remove_local_file
}

while test $# != 0
do
  case $1 in
  --update_file)
  shift
  update_file=$1
  ;;
  --recovery_file)
  shift
  recovery_file=$1
  ;;
  --remote_temp_etc_path)
  shift
  remote_temp_etc_path=$1
  ;;
  --no_upload_recovery)
  shift
  no_upload_recovery=$1
  ;;
  --only_upload_recovery)
  shift
  only_upload_recovery=$1
  ;;
  --upload_recovery_website)
  shift
  upload_recovery_website=$1
  ;;
  --project_name)
  shift
  project_name=$1
  ;;
  --transfor_ftp_host)
  shift
  transfor_ftp_host=$1
  ;;
  --official_file)
  shift
  official_file=$1
  ;;
  esac
  shift
done
echo -e "\n================开始从香港ftp中转其他国家==============="
if [ "${only_upload_recovery}" != "true" ] && [ "${upload_recovery_website}" != "true" ];then
  echo -e "需要从香港ftp中转其他国家的升级包:\n[${update_file}]\n"
fi
if [ "${no_upload_recovery}" != "true" ] && [ "${upload_recovery_website}" != "true" ];then
  echo -e "需要从香港ftp中转其他国家的recovery包:\n[${recovery_file}]\n"
fi
#trap '' INT
overseas_upload
