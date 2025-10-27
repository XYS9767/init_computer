#!/bin/bash

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用root权限运行此脚本 (sudo $0)"
    exit 1
fi

# 定义阿里云NTP服务器
ALIBABA_NTP_SERVERS=(
    "ntp.aliyun.com iburst"
    "time1.aliyun.com iburst"
    "time2.aliyun.com iburst"
    "time3.aliyun.com iburst"
)

# 检测操作系统类型并设置包管理器命令
detect_package_manager() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                PKG_MANAGER="apt"
                INSTALL_CMD="apt install -y"
                ;;
            centos|rhel|fedora)
                PKG_MANAGER="yum"
                if command -v dnf &> /dev/null; then
                    PKG_MANAGER="dnf"
                    INSTALL_CMD="dnf install -y"
                else
                    INSTALL_CMD="yum install -y"
                fi
                ;;
            *)
                echo "不支持的操作系统: $ID"
                exit 1
                ;;
        esac
    else
        echo "无法检测操作系统类型"
        exit 1
    fi
}

# 检查时间是否同步正常
check_time_normal() {
    echo "检查时间同步状态..."
    if timedatectl | grep -q "System clock synchronized: yes"; then
        # 进一步检查时间偏差是否在可接受范围内（小于1秒）
        if chronyc tracking >/dev/null 2>&1; then
            offset=$(chronyc tracking | grep "System time" | awk '{print $4}')
            if (( $(echo "$offset < 1.0 && $offset > -1.0" | bc -l) )); then
                echo "时间同步正常，偏差: $offset 秒"
                return 0
            else
                echo "时间偏差过大: $offset 秒"
                return 1
            fi
        else
            echo "chrony未运行，无法检查精确时间偏差"
            return 1
        fi
    else
        echo "时间未同步"
        return 1
    fi
}

# 检查chrony是否已安装
check_chrony_installed() {
    if command -v chronyd &> /dev/null; then
        echo "chrony已安装"
        return 0
    else
        echo "chrony未安装"
        return 1
    fi
}

# 安装chrony
install_chrony() {
    echo "正在安装chrony..."
    $INSTALL_CMD chrony
    if [ $? -ne 0 ]; then
        echo "chrony安装失败"
        exit 1
    fi
    echo "chrony安装成功"
}

# 配置chrony服务自动启动
enable_chrony_service() {
    echo "配置chrony服务自动启动..."
    systemctl enable chronyd
    systemctl start chronyd
    
    # 检查服务状态
    if systemctl is-active --quiet chronyd; then
        echo "chrony服务已启动并设置为开机自启"
    else
        echo "chrony服务启动失败"
        exit 1
    fi
}

# 配置阿里云NTP服务器
configure_ntp_servers() {
    local config_file="/etc/chrony.conf"
    local backup_file="${config_file}.bak"
    
    echo "正在配置阿里云NTP服务器..."
    
    # 备份原始配置文件（只备份一次）
    if [ ! -f "$backup_file" ]; then
        cp "$config_file" "$backup_file"
        echo "已备份原始配置文件到 $backup_file"
    fi
    
    # 检查是否已配置阿里云服务器
    if grep -q "ntp.aliyun.com" "$config_file"; then
        echo "已配置阿里云NTP服务器，无需重复配置"
        return
    fi
    
    # 删除现有的server配置
    sed -i '/^server/d' "$config_file"
    
    # 添加阿里云NTP服务器
    for server in "${ALIBABA_NTP_SERVERS[@]}"; do
        echo "server $server" >> "$config_file"
    done
    
    # 重启chrony服务使配置生效
    systemctl restart chronyd
    echo "阿里云NTP服务器配置完成"
}

# 强制同步时间直到成功
force_sync_time() {
    echo "开始强制时间同步..."
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "第 $attempt 次同步尝试..."
        chronyc -a makestep
        
        # 等待几秒钟让同步完成
        sleep 3
        
        if check_time_normal; then
            echo "时间同步成功！"
            return 0
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "经过 $max_attempts 次尝试，时间同步仍未成功"
    return 1
}

# 显示当前时间状态
show_time_status() {
    echo "==================== 当前时间状态 ===================="
    timedatectl
    echo "======================================================"
    if command -v chronyc &> /dev/null; then
        chronyc tracking
        echo "======================================================"
        chronyc sources -v | head -n 10
    fi
    echo "======================================================"
}

# 主程序
main() {
    # 先检查时间是否正常
    if check_time_normal; then
        show_time_status
        echo "时间状态正常，无需进一步操作"
        exit 0
    fi
    
    # 时间不正常，进行后续操作
    detect_package_manager
    
    # 检查并安装chrony
    if ! check_chrony_installed; then
        install_chrony
    fi
    
    # 确保服务启动并设置自动启动
    enable_chrony_service
    
    # 配置阿里云时间服务器
    configure_ntp_servers
    
    # 强制同步时间
    force_sync_time
    
    # 显示最终状态
    show_time_status
    
    echo "操作完成"
}

# 运行主程序
main

