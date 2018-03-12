#!/bin/sh

export ANSIBLE_HOSTS=/etc/ansible/ec2.py
export EC2_INI_PATH=/etc/ansible/ec2.ini 
python /etc/ansible/script.py
