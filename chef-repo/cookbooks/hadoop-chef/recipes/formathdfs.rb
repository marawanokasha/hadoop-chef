# Stop the cluster, Format the namenode and recreate the folder structure then start the cluster
hadoop_user = node['general-config']['system-user']
hadoop_path = node['general-config']['hadoop-install-path']

bash "stop cluster, format, start" do
  user "#{hadoop_user}"
  code <<-EOH
  #{hadoop_path}/sbin/stop-dfs.sh
  #{hadoop_path}/sbin/stop-yarn.sh
  #{hadoop_path}/bin/hadoop namenode -format -force
  #{hadoop_path}/sbin/start-dfs.sh
  #{hadoop_path}/sbin/start-yarn.sh
  #{hadoop_path}/bin/hdfs dfs -mkdir /user/
  #{hadoop_path}/bin/hdfs dfs -mkdir /user/#{hadoop_user}/
  EOH
end

