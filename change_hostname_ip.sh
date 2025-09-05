#!/bin/bash

# 检查脚本是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 权限运行此脚本。"
    exit 1
fi

# 函数：更改主机名
change_hostname() {
    read -p "请输入新的主机名: " new_hostname
    if [ -n "$new_hostname" ]; then
        if [ -f /etc/redhat-release ]; then
            # Red Hat 系列系统
            hostnamectl set-hostname "$new_hostname"
            sed -i "s/^127.0.0.1.*localhost/127.0.0.1 $new_hostname localhost/" /etc/hosts
            sed -i "s/^::1.*localhost/::1 $new_hostname localhost/" /etc/hosts
        elif [ -f /etc/debian_version ]; then
            # Debian 系列系统
            echo "$new_hostname" > /etc/hostname
            hostname "$new_hostname"
            sed -i "s/^127.0.0.1.*localhost/127.0.0.1 $new_hostname localhost/" /etc/hosts
            sed -i "s/^::1.*localhost/::1 $new_hostname localhost/" /etc/hosts
        else
            echo "不支持的系统类型。"
            exit 1
        fi
        echo "主机名已更改为 $new_hostname。"
    else
        echo "主机名不能为空，请重新运行脚本并输入有效的主机名。"
        exit 1
    fi
}

# 函数：更改 IP 地址
change_ip() {
    read -p "请输入新的 IP 地址: " new_ip
    if [ -n "$new_ip" ]; then
        if [ -f /etc/redhat-release ]; then
            # Red Hat 系列系统
            interface=$(ip -o -4 route show to default | awk '{print $5}')
            cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$interface
TYPE=Ethernet
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
NAME=$interface
DEVICE=$interface
ONBOOT=yes
GATEWAY=192.168.9.1
DNS1=223.5.5.5
DNS2=114.114.114.114
IPADDR=$new_ip
EOF
            systemctl restart network
        elif [ -f /etc/debian_version ]; then
            # Debian 系列系统
            interface=$(ip -o -4 route show to default | awk '{print $5}')
            cat <<EOF > /etc/network/interfaces.d/$interface
auto $interface
iface $interface inet static
    address $new_ip
EOF
            ifdown $interface && ifup $interface
        else
            echo "不支持的系统类型。"
            exit 1
        fi
        echo "IP 地址已更改为 $new_ip。"
    else
        echo "IP 地址不能为空，请重新运行脚本并输入有效的 IP 地址。"
        exit 1
    fi
}

# 主菜单
while true; do
    echo "请选择要执行的操作:"
    echo "1. 更改主机名"
    echo "2. 更改 IP 地址"
    echo "3. 退出"
    read -p "请输入选项编号: " choice

    case $choice in
        1)
            change_hostname
            ;;
        2)
            change_ip
            ;;
        3)
            echo "退出脚本。"
            break
            ;;
        *)
            echo "无效的选项，请输入 1、2 或 3。"
            ;;
    esac
done

