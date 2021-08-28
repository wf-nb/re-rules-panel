#!/bin/bash
#
# IP盾构机被控端辅助脚本 by 良辰
#
# Copyright (c) 2020.


add_crontab() {
  crontab -l 2>/dev/null >$0.temp
  echo "$*" >>$0.temp &&
    crontab $0.temp &&
    rm -f $0.temp &&
    echo -e "添加crontab成功 !" && crontab -l
}


# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -q "dash"; then
	echo "This script needs to be run with bash, not sh"
	exit
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit
fi

if ! iptables -t nat -nL &>/dev/null; then
	echo "您似乎未安装iptables."
	exit
fi



beikong0_chushihua(){
	if grep -qs "14.04" /etc/os-release; then
	echo "Ubuntu 14.04 is not supported"
	exit
fi

if grep -qs "jessie" /etc/os-release; then
	echo "Debian 8 is not supported"
	exit
fi

if grep -qs "CentOS release 6" /etc/redhat-release; then
	echo "CentOS 6 is not supported"
	exit
fi

	echo "请输入当前机器主网卡名，例如eth0："
	read -p "eth name: " eth_name
	echo "请输入当前机器总带宽速率(单位Mbps)："
	read -p "须为大于0的正整数: " port_speed
	echo "开启iptables转发模块..."
	echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	sysctl -p
	echo "正在清空防火墙..."
	iptables -F
	iptables -t nat -F
	echo "正在清空限速规则..."
	iptables -t mangle -F
	echo "正在初始化tc限速(无视报错即可)..."
	tc qdisc del dev "$eth_name" root
	echo "正在tc限速添加根节点..."
	tc qdisc add dev "$eth_name" root handle 1: htb default 1
	tc class add dev "$eth_name" parent 1: classid 1:1 htb rate "$port_speed"mbps
	echo "保存防火墙..."
	if [[ "$release" == "centos" ]]; then
		service iptables save
		echo "安装curl..."
		yum install wget -y
		yum install curl -y
		yum install ca-certificates -y
		echo "修改profile权限"
		chmod 777 /etc/profile
	else
		iptables-save > /etc/iptables.up.rules
		echo "安装curl..."
		apt-get install wget -y
		apt-get install curl -y
		apt-get install ca-certificates -y
		echo "修改profile权限"
		chmod 777 /etc/profile
	fi
	echo "初始化完毕！"
	read -p "是否安装被控端文件(首次执行必须安装)[y/N]" down_files
	if [[ "$down_files" =~ ^[yY]$ ]]; then
		echo "正在下载gost2.11版本"
		wget https://zf.scrssr.com/sh/gost -O /usr/bin/gost
		chmod +x /usr/bin/gost
		echo "正在下载被控端"
		wget https://zf.scrssr.com/sh/ip_table -O /usr/bin/ip_table
		chmod +x /usr/bin/ip_table
		echo "正在下载brook"
		wget https://zf.scrssr.com/sh/brook -O /usr/bin/brook
		chmod +x /usr/bin/brook
	fi
    read -p "请输入主控网址，例如https://zf.scrssr.com :" URL
    read -p "请输入中转机密钥 :" KEY
    add_crontab "*/1 * * * * . /etc/profile;ip_table -url $URL -key $KEY   >> /root/iptables.log 2>&1"
}
beikong1_chushihua(){
	echo "正在执行初始化，请提前手动放行防火墙！"
	if [[ "$release" == "centos" ]]; then
		yum install wget -y
		yum install curl -y
		yum install ca-certificates -y
	else
                apt-get install wget -y
		apt-get install curl -y
		apt-get install ca-certificates -y
	fi
	echo "初始化完毕！"
	read -p "是否下载被控端文件(首次执行必须安装)[y/N]" down_files_1
	if [[ "$down_files_1" =~ ^[yY]$ ]]; then
		echo "正在下载gost2.11版本"
		wget https://zf.scrssr.com/sh/gost -O /usr/bin/gost
		chmod +x /usr/bin/gost
		echo "正在下载被控端"
		wget https://zf.scrssr.com/sh/iptables_gost -O /usr/bin/iptables_gost
		chmod +x /usr/bin/iptables_gost
	fi
	read -p "请输入主控网址，例如https://zf.scrssr.com :" URL
    read -p "请输入落地机密钥 :" KEY
    add_crontab "*/1 * * * * . /etc/profile;iptables_gost -url $URL -key $KEY >> /root/iptables.log 2>&1"
}
install_iptables(){
	iptables_exist=$(iptables -V)
	if [[ ${iptables_exist} != "" ]]; then
		echo -e "${Info} 已经安装iptables，继续..."
	else
		echo -e "${Info} 检测到未安装 iptables，开始安装..."
		if [[ ${release}  == "centos" ]]; then
			yum update
			yum install -y iptables
			yum install -y iptables-services
		else
			apt-get update
			apt-get install -y iptables
			apt-get install -y iptables-services
		fi
		iptables_exist=$(iptables -V)
		if [[ ${iptables_exist} = "" ]]; then
			echo -e "${Error} 安装iptables失败，请检查 !" && exit 1
		else
			echo -e "${Info} iptables 安装完成 !"
		fi
	fi
	echo -e "${Info} 开始配置 iptables !"
	Set_iptables
	echo -e "${Info} iptables 配置完毕 !"
}
#开始菜单
start_menu(){
clear
echo && echo -e " IP盾构机辅助脚本 V2.0.0 kedou修复版
 ${Green_font_prefix}0.${Font_color_suffix} 安装iptables
 ${Green_font_prefix}1.${Font_color_suffix} 转发机-全局初始化
 ${Green_font_prefix}2.${Font_color_suffix} 落地机-全局初始化" && echo
stty erase '^H' && read -p " 请输入数字 [1-2]:" num
case "$num" in
    0)
    install_iptables
    ;;
	1)
	beikong0_chushihua
	;;
	2)
	beikong1_chushihua
	;;
	*)
        clear
	echo -e "${Error}:请输入正确数字"
	sleep 2s
	start_menu
	;;
esac
}


#############系统检测组件#############

#检查系统
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
}

#检查Linux版本
check_version(){
	if [[ -s /etc/redhat-release ]]; then
		version=`grep -oE  "[0-9.]+" /etc/redhat-release | cut -d . -f 1`
	else
		version=`grep -oE  "[0-9.]+" /etc/issue | cut -d . -f 1`
	fi
	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		bit="x64"
	else
		bit="x32"
	fi
}



#############系统检测组件#############
check_sys
check_version
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
start_menu
