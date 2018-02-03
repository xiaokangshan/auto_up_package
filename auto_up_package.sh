#!/bin/bash

######################################
#functions: up local package to update ftp
#author: luxson
#date: 2016/08/17
######################################

# 上传在线升级包到ftp
function auto_up_package_to_ftp()
{
  update_file="$(echo "${update_file}" | tr ',' ' ')"
  recovery_file="$(echo "${recovery_file}" | tr ',' ' ')"
  if [ "${upload_recovery_website}" == "true" ];then
    update_file="${recovery_file}"
  fi
  no_exist_file_list=
  for file in ${update_file};do
    if [ ! -f "${local_update_path}${file}" ];then
      no_exist_file_list="${no_exist_file_list} ${file}"
    fi
  done
  tmp_fifofile="/tmp/$$.fifo"
  mkfifo $tmp_fifofile
  exec 4<>$tmp_fifofile
  rm $tmp_fifofile
  for ((i=0;i<${thread};i++));do
    echo ""
  done >&4
  if [ "${only_upload_recovery}" != "true" ];then
    for file in ${update_file}
    do
    if [ -f "${local_update_path}${file}" ];then
      read -u4
      {
      echo "正在上传${file}升级包，请稍后..."
      ${connect_ftp} <<EOF
      cd ${update_ftp_path}
      lcd ${local_update_path}
      put ${file}
      bye
EOF
      sleep 3
      echo "" >&4
      }&
    fi
    done
  fi
  if [ "${upload_recovery_website}" != "true" ];then
    if [ -n "${recovery_file}" ] && [ "${no_upload_recovery}" != "true" ];then
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
  fi
wait
exec 4>&-

  if [ -n "$(echo "${no_exist_file_list}")" ];then
    no_exist_file_list="$(echo ${no_exist_file_list})"
    echo -e "\n香港ftp缺少升级包(${no_exist_file_list}),请先上传!" && exit 1
  fi
}

# 删除本地临时文件
function remove_local_file()
{
  #echo "==================开始删除本次中转站的临时文件========================="
  for file in ${update_file};do
    if [ -f "${local_update_path}${file}" ];then
      rm -rf "${local_update_path}${file}"
    fi
  done
  if [ -f "${local_recovery_path}${recovery_file}" ];then
    rm -rf "${local_recovery_path}${recovery_file}"
  fi
  #echo "=================删除本次中转站的临时文件结束=========================="
}

# ftp代理服务器修改etc文件
function modify_etc_file()
{
  if [ -z "`cat "${etc_file}" | grep "${proxy_ip}"`" ];then
    first_nu="`echo "${proxy_ip}" | awk -F '.' '{print $1}'`"
    local_modify="`cat /etc/tsocks.conf | grep ^"local =" | grep 255.0.0 | awk -F '=' '{print $2}'`"
    server_modify="`cat /etc/tsocks.conf | grep ^"server =" | awk -F '=' '{print $2}'`"
    proxy_user_modify="`cat /etc/tsocks.conf | grep ^"default_user =" | awk -F '=' '{print $2}'`"
    proxy_pass_modify="`cat /etc/tsocks.conf | grep ^"default_pass =" | awk -F '=' '{print $2}'`"
    current_etc_path="/data/www/upgrade/project/${remote_temp_etc_path}"
    mkdir -p ${current_etc_path}
    cp /etc/tsocks.conf ${current_etc_path}/tsocks.conf
    sed -i "s#${local_modify}# ${first_nu}.0.0.0/255.0.0.0#g" ${current_etc_path}/tsocks.conf
    sed -i "s#${server_modify}# ${proxy_ip}#g" ${current_etc_path}/tsocks.conf
    sed -i "s#${proxy_user_modify}# ${proxy_user}#g" ${current_etc_path}/tsocks.conf
    sed -i "s#${proxy_pass_modify}# ${proxy_pass}#g" ${current_etc_path}/tsocks.conf
    cp ${current_etc_path}/tsocks.conf /etc/tsocks.conf
  fi
}

# 外销传升级包入口
function overseas_upload()
{
  update_ftp_path="/upload/UpdateFiles/"
  recovery_ftp_path="/recovery/recoveryFiles/"
  local_update_path="/data/www/upgrade/upload/UpdateFiles/"
  local_recovery_path="/data/www/upgrade/recovery/recoveryFiles/"
  thread=4
  etc_file="/etc/tsocks.conf"
  transfor_ftp_host="$(echo "${transfor_ftp_host}" | tr ',' ' ')"
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
  for ftp_host in ${transfor_ftp_host};do
    if [ "${ftp_host}" == "192.168.0.126" ];then
      user=exupgrade
      pass=BoUVmerZMGRuB4N2
      proxy_ip="13.126.57.77"
      proxy_user="exupgrade"
      proxy_pass="BoUVmerZMGRuB4N2"
      echo "${project_name}项目升级包正在从香港ftp中转到印度ftp..."
    elif [ "${ftp_host}" == "10.60.0.216" ];then
      if [ -z "${is_upload_to_ru}" ];then
        continue
      fi
      user=exupgrade
      pass=BoUVmerZMGRuB4N2
      proxy_ip="128.1.43.63"
      proxy_user="exupgrade"
      proxy_pass="BoUVmerZMGRuB4N2"
      echo "${project_name}项目升级包正在从香港ftp中转到俄罗斯ftp..."
    fi
    connect_ftp="tsocks lftp -u ${user},${pass} ftp://${ftp_host}:21"

    # 修改ftp代理服务器etc文件
    modify_etc_file

    # 上传升级包
    auto_up_package_to_ftp
  done
  #if [ "${remove_package_sum}" -ge "1" ];then
    # 将传输完的文件删除
    remove_local_file
  #fi
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
  --remove_package_sum)
  shift
  remove_package_sum=$1
  ;;
  --is_upload_to_ru)
  shift
  is_upload_to_ru=$1
  ;;
  esac
  shift
done
echo -e "\n================开始从香港ftp中转其他国家==============="
if [ "${only_upload_recovery}" != "true" ];then
  echo -e "需要从香港ftp中转其他国家的升级包:\n[${update_file}]\n"
fi
if [ "${no_upload_recovery}" != "true" ] && [ "${upload_recovery_website}" != "true" ];then
  echo -e "需要从香港ftp中转其他国家的recovery包:\n[${recovery_file}]\n"
fi
#trap '' INT
overseas_upload
