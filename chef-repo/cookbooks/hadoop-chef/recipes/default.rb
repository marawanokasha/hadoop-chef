###############################################################################
###### Chef Recipe for setting up Hadoop and its dependencies #################


####### add nameservers to make sure we can get the java package if we need
dns_nameservers_found = File.open('/etc/network/interfaces').read().index('dns-nameservers')
ruby_block 'add dns nameservers' do
  block do
    fe = Chef::Util::FileEdit.new("/etc/network/interfaces")
    fe.insert_line_if_no_match(/#{'dns-nameservers'}/,
                               "\ndns-nameservers 8.8.8.8 8.8.4.4")
    fe.write_file
  end
  not_if {dns_nameservers_found}
end
# restart networking so that dns-nameserver changes take effect
execute 'restart networking' do
    command 'sudo service resolvconf restart'
    only_if {!dns_nameservers_found}
end


####### execute apt-get update to refresh the repositories
execute "apt-get-update" do
  command "sudo apt-get update"
  ignore_failure true
  not_if do ::File.exists?('/var/lib/apt/periodic/update-success-stamp') end
end


####### Installation of prerequisites
# install java if not installed
package 'openjdk-7-jdk'
# used for ssh public key copying the first time
package 'sshpass'


####### Initialize some vars we'll need later
hadoop_user = node['general-config']['system-user']
hadoop_group = node['general-config']['system-user-group']
# only used on initialization to copy the public key from namenode to datanode
hadoop_user_pass = node['general-config']['system-user-pass']
# Create workspace where we download and setup everything
hadoop_path = node['general-config']['hadoop-install-path']
workspace_path = node['general-config']['workspace-path']


####### determine if this is namenode or not, will be used later
allIps = node["network"]["interfaces"].keys.map { |iface_name| node["network"]["interfaces"][iface_name]["addresses"].keys[1] }
isNameNode = allIps.include? node['hadoop-config']['namenode']['ip']
puts("Configuring NameNode: " + isNameNode.to_s)


####### Create hadoop and temp directories
[ hadoop_path, workspace_path ].each do |path|
  directory path do
    owner 'ubuntu'
    group 'ubuntu'
    mode '0755'
  end
end


####### Download Hadoop Tar
hadoop_tar = File.join(workspace_path,"hadoop.tar.gz")
hadoop_source_url = node['general-config']['hadoop-source-url']
remote_file hadoop_tar do
        source hadoop_source_url
        mode "0777"
        owner "ubuntu"
        group "ubuntu"
        not_if { File.exists?(File.join(hadoop_path,'etc')) }
end


####### Unzip tar
execute "untar and move hadoop" do
        cwd workspace_path
        command "tar -xzf hadoop.tar.gz && rm hadoop.tar.gz && mv hadoop* hadoop&& chown -R #{hadoop_user}:#{hadoop_group} hadoop && mv hadoop/* #{hadoop_path} && rm -r hadoop"
        not_if { File.exists?(File.join(hadoop_path,'etc')) }
end


####### add JAVA_HOME to hadoop-env.sh
ruby_block 'add JAVA_HOME to hadoop-env.sh' do
  block do
    fe = Chef::Util::FileEdit.new(File.join(hadoop_path,'etc/hadoop/hadoop-env.sh'))
    fe.search_file_replace_line('export JAVA_HOME', "export JAVA_HOME=#{node['general-config']['java-path']}")
    fe.write_file
  end
  only_if {File.open(File.join(hadoop_path,'etc/hadoop/hadoop-env.sh')).read().index('JAVA_HOME=${JAVA_HOME}')}
end


####### add HADOOP_PREFIX/bin to .bashrc
added_to_bashrc = false
ruby_block 'add HADOOP_PREFIX to .bashrc' do
  block do
    fe = Chef::Util::FileEdit.new("/home/#{hadoop_user}/.bashrc")
    fe.insert_line_if_no_match('export HADOOP_PREFIX', <<-EOH 
export HADOOP_PREFIX=#{hadoop_path}
export PATH=$PATH:$HADOOP_PREFIX/sbin:$HADOOP_PREFIX/bin
EOH
)
    fe.write_file
    added_to_bashrc = true
  end
  only_if {!File.open("/home/#{hadoop_user}/.bashrc").read().index('export HADOOP_PREFIX')}
end
bash 'source .bashrc' do
  user "#{hadoop_user}"
  code ". /home/#{hadoop_user}/.bashrc"
  only_if{added_to_bashrc}
end


####### core-site.xml
template File.join(hadoop_path, 'etc/hadoop/core-site.xml') do
        source 'core-site.xml.erb'
        variables ({
                :nameNodeIp => node['hadoop-config']['namenode']['ip'],
                :hdfsPort => node['hadoop-config']['hdfs-port']
        })
end

####### hdfs-site.xml
template File.join(hadoop_path, 'etc/hadoop/hdfs-site.xml') do
        source 'hdfs-site.xml.erb'
        variables ({
                :secondaryNameNodeIp => node['hadoop-config']['secondary-namenode']['ip'],
                :secondaryNameNodeHttpPort => node['hadoop-config']['secondary-namenode-http-port'],
                :replicationValue => node['hadoop-config']['replication-value']
        })
end


####### yarn-site.xml
template File.join(hadoop_path, 'etc/hadoop/yarn-site.xml') do
        source 'yarn-site.xml.erb'
        variables ({
		# might be better to use a separate config property for this, but here we just use the namenode
                #:resourceManagerIp => node['hadoop-config']['resource-manager']['ip']
                :resourceManagerIp => node['hadoop-config']['namenode']['ip']
        })
end


####### mapred-site.xml
template File.join(hadoop_path, 'etc/hadoop/mapred-site.xml') do
        source 'mapred-site.xml.erb'
end


####### slaves file
template File.join(hadoop_path, 'etc/hadoop/slaves') do
	source 'slaves.erb'
	variables ({'dataNodes' => node['hadoop-config']['datanodes'] });
	only_if{isNameNode}
end


####### /etc/hosts file
template '/etc/hosts' do
        source 'hosts.erb'
        variables ({ 'nameNode' => {node['hadoop-config']['namenode']['ip'] => node['hadoop-config']['namenode']['hostname']},
                     'dataNodes' => node['hadoop-config']['datanodes']
        })
end


####### Create RSA key with empty password on namenode and copy over to datanodes
execute "create ssh key" do
  command "ssh-keygen -q -t rsa -N '' -f /home/#{hadoop_user}/.ssh/id_rsa"
  creates "/home/#{hadoop_user}/.ssh/id_rsa"
  action :run
  only_if {isNameNode}
end
# Must be done so that we don't get the "unknown host" prompt that requires user interaction when doing the ssh-copy-id.
# Chef can't handle this prompt and would throw an exception
ssh_config_file = "/home/#{hadoop_user}/.ssh/config"
file ssh_config_file do
        action :create
end
ruby_block 'disable strict host key checking' do
  block do
    fe = Chef::Util::FileEdit.new(ssh_config_file)
    fe.insert_line_if_no_match('StrictHostKeyChecking', "Host *")
    fe.insert_line_if_no_match('StrictHostKeyChecking', "StrictHostKeyChecking no")
    fe.write_file
  end
  only_if {File.open('/etc/network/interfaces').read().index('StrictHostKeyChecking')}
end
# Loop over all datanodes and copy the namenode's public key to them
dataNodes = node['hadoop-config']['datanodes']
dataNodes.each do |dataNode|
    dataNode.each do |ip,hostName|
        execute "ssh-key-copy" do
                user 'ubuntu'
                command "sshpass -p #{hadoop_user_pass} ssh-copy-id -i ~/.ssh/id_rsa.pub #{hadoop_user}@#{ip}"
                action :run
                only_if {isNameNode}
        end
    end
end
name_node_ip = node['hadoop-config']['namenode']['ip']
execute "ssh-key-copy-local" do
                user 'ubuntu'
                command "sshpass -p #{hadoop_user_pass} ssh-copy-id -i ~/.ssh/id_rsa.pub #{hadoop_user}@#{name_node_ip}"
                action :run
                only_if {isNameNode}
end

