hadoop-chef
===========

Chef script for setting up hadoop using chef-solo (for now)

There are three recipes included so far, a setup recipe (default.rb), a format recipe (formathdfs.rb) and a start recipe(starserver.rb)

Usage:

- clone the repository to your hadoop node (namenode or datanode)
- For initial setup of hadoop, edit the setup.json file to specify the correct namenode and datanode ips and hostnames
- The same goes for the format recipe config file (formathdfs.json) and the start recipe config file (startserver.json)
- solo.rb just contains the path to your cookbooks, modify as necessary according to where you cloned the repo
- To run make sure you have chef installed: $ curl -L https://www.opscode.com/chef/install.sh | sudo bash 
- Then run chef-solo specifying the correct json config file: $ sudo chef-solo -c solo.rb -j setup.json
