# Start the cluster
hadoop_user = node['general-config']['system-user']
hadoop_path = node['general-config']['hadoop-install-path']

bash "start cluster" do
  user "#{hadoop_user}"
  code <<-EOH
  #{hadoop_path}/sbin/start-dfs.sh
  #{hadoop_path}/sbin/start-yarn.sh
  EOH
end

