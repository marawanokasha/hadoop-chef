hadoop_user = node['general-config']['system-user']
# only required on initialization to copy over the ssh public key from namenode to datanode
hadoop_user_pass = node['general-config']['system-user-pass']
name_node_ip = node['hadoop-config']['namenode']['ip']


package 'sshpass'

# determine if this is a namenode or not, will be used later
allIps = node["network"]["interfaces"].keys.map { |iface_name| node["network"]["interfaces"][iface_name]["addresses"].keys[1] }
isNameNode = allIps.include? name_node_ip
puts("Configuring NameNode: " + isNameNode.to_s)


# Create RSA key with empty password
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
  only_if{!File.exists?(ssh_config_file)}
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

