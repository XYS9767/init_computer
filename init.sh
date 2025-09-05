#!/bin/bash
##############################################################
# File Name:init.sh
# Version:V1.0
# Author:oranges_are_ripe.
# Organization:https://uniqueyouzhi.feishu.cn
# Desc:输入脚本作用
##############################################################
#ansible-playbook -i host.ini  basic.yml -e  ansible.cfg
ansible-playbook -i host.ini basic-centos8.yml  -e  ansible.cfg
