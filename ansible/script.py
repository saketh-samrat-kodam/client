
import os

os.system("/etc/ansible/ec2.py --list | grep ec2__ip_address | sed -e 's/.*://' | perl -pe 's/.*\K,/ /' | sed 's/\"//g' > /etc/ansible/file.txt")

id_old = []
for line in open('/etc/ansible/file.txt','r').readlines():
    id_old.append(line.strip())
id_new = []
for line in open('/etc/ansible/copy.txt','r').readlines():
    id_new.append(line.strip())

b=list(set(id_old) ^ set(id_new))
print(b)

f=open('/etc/ansible/fnew.txt','w')
for ele in b:
    f.write(ele+'\n')

f.close()


#from subprocess import call
#call('ansible','all','-m ping')
import os
os.system("ansible-playbook sparc.yml -i fnew.txt --private-key=/etc/ansible/django.pem -u centos")


g=open('/etc/ansible/copy.txt','w')
for ele in id_old:
    g.write(ele+'\n')

g.close()


