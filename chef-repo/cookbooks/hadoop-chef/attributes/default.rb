default['general-config']['system-user'] = 'ubuntu'
default['general-config']['system-user-group'] = 'ubuntu'
# only required on initialization to transfer the ssh public key from namenode to datanode
default['general-config']['system-user-pass'] = 'ubuntu'

default['general-config']['java-path'] = '/usr/lib/jvm/java-7-openjdk-amd64/'

default['general-config']['hadoop-install-path'] = '/home/ubuntu/hadoop'
# Used inside hadoop to store temporary system files, very important to be outside of /tmp where it is by default
# because in that case, it would be deleted after every stop of hadoop and the cluster wouldn't be able to start again
# this directory doesn't have to exist beforehand
default['general-config']['hadoop-temp-path'] = '/home/ubuntu/hadoop-tmp'
# Where to download temp files
default['general-config']['workspace-path'] = 'home/ubuntu/hadoop-workspace'
default['general-config']['hadoop-source-url'] = 'http://apache.mirror.iphh.net/hadoop/common/hadoop-2.5.2/hadoop-2.5.2.tar.gz'

default['hadoop-config']['hdfs-port'] = '9000'
default['hadoop-config']['replication-value'] = '3'
default['hadoop-config']['namenode'] = {'ip' => '192.168.56.103', 'hostname' => 'ubuntu-1'}

default['hadoop-config']['secondary-namenode'] = {'ip' => '192.168.56.103'}
default['hadoop-config']['secondary-namenode-http-port'] = '50090'

# might be better to use this to add flexibility, but for now we just use the same ip as the namenode
#default['hadoop-config']['resource-manager'] = {'ip' => '192.168.56.103'}

default['hadoop-config']['datanodes'] = [ {'192.168.56.104'=>'ubuntu-2'},
				           {'192.168.56.102'=>'ubuntu-3'}]

