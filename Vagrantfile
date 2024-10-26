Vagrant.configure("2") do |config|

  config.vm.define "web" do |web|
    web.vm.box = "debian/bullseye64"
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.10"

    web.vm.provider "virtualbox" do |vb|
      vb.name = "web"
      vb.memory = "512"
      vb.cpus = 1

      vb.ssh.username = 'vagrant'
      vb.ssh.password = 'vagrant'
      vb.ssh.insert_key = false
    end
  end

  config.vm.define "bdd" do |bdd|
    bdd.vm.box = "debian/bullseye64"
    bdd.vm.hostname = "bdd"
    bdd.vm.network "private_network", ip: "192.168.56.11"

    bdd.vm.provider "bdd" do |vb|
      vb.name = "bdd"
      vb.memory = "512"
      vb.cpus = 1

      vb.ssh.username = 'vagrant'
      vb.ssh.password = 'vagrant'
      vb.ssh.insert_key = false
    end
  end

end
