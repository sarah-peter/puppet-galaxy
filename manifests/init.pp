# == Class: galaxy
#
# This module sets up a Galaxy server according to the specific requirements
# of the University of Luxembourg's HPC group and the LCSB.
#
# === Parameters
#
# [*postgresql_password*]
#   This should be replaced by a secure password.
#
# [*id_secret*]
#   Galaxy encodes various internal values when these values will be output in
#   some format (for example, in a URL or cookie).  You should set a key to be
#   used by the algorithm that encodes and decodes these values.  It can be any
#   string.  If left unchanged, anyone could construct a cookie that would grant
#   them access to others' sessions.
#
# [*directory*]
#   The main directory for the Galaxy instance, where all the code and
#   configurations reside.
#
# === Variables
#
# This module does not require any variables.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'galaxy':
#    postgresql_password => 'securepassword',
#  }
#
# === Authors
#
# Sarah Diehl <sarah.diehl@uni.lu>
#
# === Copyright
#
# Copyright 2015 Sarah Diehl
#

class galaxy (
  $postgresql_password = $galaxy::params::postgresql_password,
  $id_secret           = $galaxy::params::id_secret,
  $directory           = $galaxy::params::directory,
  $galaxy_data_dir     = $galaxy::params::galaxy_data_dir,
) inherits galaxy::params {

  $config_files        = [ "${directory}/config/galaxy.ini", "${directory}/config/job_conf.xml", "${directory}/config/tool_conf.xml",
                           "${directory}/config/shed_tool_conf.xml", "${directory}/config/tool_sheds_conf.xml" ]

  # Packages
  package { [ 'gcc', 'mercurial', 'tar', 'python', 'openssl', 'git', 'zlib1g-dev', 'python-dev', 'python-setuptools', 'python-pip',
              'make', 'g++', 'gfortran', 'samtools', 'proftpd', 'proftpd-mod-ldap', 'pkg-config', 'gnuplot', 'python-gnuplot', 'python-virtualenv',
              'openjdk-7-jre-headless' ]:
    ensure => 'present',
  }

  # configure exim4 for mail notifications
  class { 'exim4':
    configtype => 'satellite',
    smarthost  => 'smtp.uni.lu'
  }

  # user and group
  group { 'galaxy':
    ensure => 'present',
    gid    => '2124',
  }

  user { 'galaxy':
    ensure     => 'present',
    comment    => 'user for Galaxy server',
    uid        => '5432',
    home       => '/home/galaxy',
    gid        => 'galaxy',
    managehome => true,
    shell      => '/bin/bash',
    require    => Group[ 'galaxy' ],
  }
  
  # SSH key and configuration to connect to cluster
  ssh_keygen { 'galaxy':
    bits    => '4096',
    require => User['galaxy'],
  }

  file { '/home/galaxy/.ssh/config':
    ensure  => 'present',
    source  => 'puppet:///modules/galaxy/ssh_config',
    owner   => 'galaxy',
    group   => 'galaxy',
    require => Ssh_keygen['galaxy'],
  }


  # Mounts of project directories
  class { 'galaxy::directorystructure': }
  #galaxy::projectmount { 'biocore': }

  # Apache setup
  class { 'apache':
    default_mods        => false,
    default_confd_files => false,
    default_vhost       => false,
  }

  apache::listen { '80': }
  apache::listen { '443': }

  include apache::mod::xsendfile
  include apache::mod::rewrite
  include apache::mod::ssl
  include apache::mod::proxy
  include apache::mod::proxy_balancer
  include apache::mod::authnz_ldap
  include apache::mod::auth_basic
  include apache::mod::headers
  include apache::mod::expires
  include apache::mod::mime
  include apache::mod::setenvif
  apache::mod { 'authz_user': }

  exec { 'apache_access':
    command => 'usermod -a -G galaxy www-data',
    path    => [ '/usr/bin', '/usr/sbin' ],
    require => Class['apache'],
    notify  => Service['apache2'],
  }

  file { '/etc/ssl/localcerts':
    ensure => 'directory',
  }

  exec {  'create_self_signed_sslcert':
    command => "openssl req -newkey rsa:2048 -nodes -keyout apache.key  -x509 -days 365 -out apache.pem -subj '/CN=galaxy-server.uni.lu'",
    cwd     => '/etc/ssl/localcerts',
    creates => [ '/etc/ssl/localcerts/apache.key', '/etc/ssl/localcerts/apache.pem', ],
    path    => [ '/usr/bin', '/usr/sbin' ],
    require => File['/etc/ssl/localcerts'],
  }

  file { '/etc/apache2/sites-available/galaxy.conf':
    ensure  => 'present',
    content => template('galaxy/galaxy.conf.erb'),
    owner   => 'root',
    backup  => '.puppet-bak',
    require => [ Class[ 'apache' ], Exec[ 'create_self_signed_sslcert' ] ],
  }

  exec { 'a2ensite':
    command => 'a2ensite galaxy.conf',
    creates => '/etc/apache2/sites-enabled/galaxy.conf',
    path    => [ '/usr/bin', '/usr/sbin' ],
    require => File['/etc/apache2/sites-available/galaxy.conf'],
    notify  => Service['apache2'],
  }

  # ProFTP Setup
  exec {  'create_self_signed_sslcert_ftp':
    command => "openssl req -newkey rsa:2048 -nodes -keyout proftpd.key  -x509 -days 365 -out proftpd.crt -subj '/CN=galaxy-server.uni.lu'",
    cwd     => '/etc/ssl/localcerts',
    creates => [ '/etc/ssl/localcerts/proftpd.key', '/etc/ssl/localcerts/proftpd.pem', ],
    path    => [ '/usr/bin', '/usr/sbin' ],
    require => File['/etc/ssl/localcerts'],
  }

  file { '/etc/proftpd/proftpd.conf':
    ensure  => 'present',
    content => template('galaxy/proftpd.conf.erb'),
    owner   => 'root',
    backup  => '.puppet-bak',
    require => [ Package[ 'proftpd' ], Exec[ 'create_self_signed_sslcert_ftp' ] ],
    notify  => Service['proftpd'],
  }

  service { 'proftpd':
    ensure  => 'running',
    require => File['/etc/proftpd/proftpd.conf'],
  }


  # PostGreSQL setup
  class { 'postgresql::server': }

  postgresql::server::db { 'galaxy':
    user     => 'galaxy',
    password => postgresql_password('galaxy', $postgresql_password),
  }

  postgresql::server::db { 'galaxytools':
    user     => 'galaxy',
    password => postgresql_password('galaxy', $postgresql_password),
  }

  postgresql::server::db { 'toolshed':
    user     => 'galaxy',
    password => postgresql_password('galaxy', $postgresql_password),
  }

  # Galaxy setup
  vcsrepo { $directory:
    ensure              => 'present',
    user                => 'galaxy',
    provider            => 'git',
    source              => $galaxy::params::repository,
    revision            => $galaxy::params::branch,
    require             => User['galaxy'],
  }

  file { "${directory}/config/galaxy.ini":
    ensure  => 'present',
    content => template("galaxy/galaxy.ini.erb"),
    owner   => 'galaxy',
    group   => 'galaxy',
    replace => false,
    require => Vcsrepo[$directory],
  }

  file { "${directory}/config/job_conf.xml":
    ensure  => 'present',
    source  => 'puppet:///modules/galaxy/job_conf.xml',
    owner   => 'galaxy',
    group   => 'galaxy',
    replace => false,
    require => Vcsrepo[$directory],
  }

  file { "${directory}/config/tool_conf.xml":
    ensure  => 'present',
    source  => 'puppet:///modules/galaxy/tool_conf.xml',
    owner   => 'galaxy',
    group   => 'galaxy',
    replace => false,
    require => Vcsrepo[$directory],
  }

  file { "${directory}/config/shed_tool_conf.xml":
    ensure  => 'present',
    content => template("galaxy/shed_tool_conf.xml.erb"),
    owner   => 'galaxy',
    group   => 'galaxy',
    replace => false,
    require => Vcsrepo[$directory],
  }

  file { "${directory}/config/tool_sheds_conf.xml":
    ensure  => 'present',
    source  => 'puppet:///modules/galaxy/tool_sheds_conf.xml',
    owner   => 'galaxy',
    group   => 'galaxy',
    replace => false,
    require => Vcsrepo[$directory],
  }

  exec { 'common startup':
    path    => '/usr/bin:/usr/sbin:/bin:/sbin',
    cwd     => $directory,
    command => "${directory}/scripts/common_startup.sh",
    user    => 'galaxy',
    group   => 'galaxy',
    require => [ Vcsrepo[$directory], File[$config_files], Package['python'] ],
  }

  exec { 'create db':
    path    => '/usr/bin:/usr/sbin:/bin:/sbin',
    cwd     => $directory,
    command => "python ${directory}/scripts/create_db.py; python ${directory}/scripts/manage_db.py upgrade",
    user    => 'galaxy',
    group   => 'galaxy',
    require => [ Exec['common startup'], PostGreSQL::Server::DB['galaxy', 'galaxytools'], Service['postgresql'], Package['python'] ],
  }

  # service setup
  file { '/etc/init.d/galaxy':
    ensure => 'present',
    source => 'puppet:///modules/galaxy/galaxy',
    owner  => 'root',
  }

  # virtualenv setup
  exec { 'virtualenv':
    path    => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin',
    cwd     => $galaxy_data_dir,
    command => "virtualenv .venv",
    user    => 'galaxy',
    group   => 'galaxy',
    require => [ Class['galaxy::directorystructure'], Package['python-virtualenv'] ],
  }

  service { 'galaxy':
    ensure     => 'running',
    enable     => 'true',
    hasrestart => 'true',
    hasstatus  => 'true',
    require    => [ File['/etc/init.d/galaxy'], Exec['create db', 'a2ensite', 'virtualenv'], Service['apache2', 'postgresql'],
                    Class['galaxy::directorystructure'] ],
  }

  # Update genome builds
  exec { 'update_ucsc':
    command => "cat updateucsc.sh.sample | sed 's|#GALAXY=/galaxy/path|GALAXY=${directory}|' > updateucsc.sh && bash updateucsc.sh",
    path    => '/usr/bin:/usr/sbin:/bin:/sbin',
    creates => "${directory}/cron/updateucsc.sh",
    cwd     => "${directory}/cron",
    user    => 'galaxy',
    group   => 'galaxy',
    timeout => 7200,
    require => Vcsrepo[$directory],
    notify  => Service['galaxy'],
  }

  # Set up local tool shed
  file { "${directory}/config/tool_shed.ini":
    ensure  => 'present',
    content => template("galaxy/tool_shed.ini.erb"),
    owner   => 'galaxy',
    group   => 'galaxy',
    replace => false,
    require => Vcsrepo[$directory],
  }

  file { '/etc/init.d/toolshed':
    ensure => 'present',
    source => 'puppet:///modules/galaxy/toolshed',
    owner  => 'root',
  }

  exec { 'toolshed db':
    path    => '/usr/bin:/usr/sbin:/bin:/sbin',
    cwd     => $directory,
    command => "python ${directory}/scripts/manage_db.py upgrade tool_shed",
    user    => 'galaxy',
    group   => 'galaxy',
    require => [ PostGreSQL::Server::DB['toolshed'], Service['postgresql'], Package['python'] ],
  }

  service { 'toolshed':
    ensure     => 'running',
    enable     => 'true',
    hasrestart => 'true',
    hasstatus  => 'true',
    require    => [ File['/etc/init.d/toolshed', "${directory}/config/tool_shed.ini"], Service['apache2', 'postgresql'],
                    Exec['toolshed db']],
  }



  # Regular maintenance: clean up deleted datasets and backup
  file { "${directory}/cron/cleanup_cron.sh":
    ensure  => 'present',
    content => template("galaxy/cleanup_cron.sh.erb"),
    owner   => 'galaxy',
    group   => 'galaxy',
    require => Vcsrepo[$directory],
  }

  cron {'cleanup datasets':
    ensure   => present,
    command  => "/bin/bash ${directory}/cron/cleanup_cron.sh",
    user     => 'galaxy',
    monthday => 15,
    hour     => 1,
    minute   => 5,
    require  => File["${directory}/cron/cleanup_cron.sh"],
  }

  file { "${galaxy::params::backup_dir}/postgres":
    ensure => 'directory',
    owner  => 'galaxy',
    group  => 'galaxy',
  }

  cron {'postgres dump galaxy':
    ensure  => 'present',
    command => "/usr/bin/pg_dump galaxy > ${galaxy::params::backup_dir}/postgres/galaxy.sql",
    user    => 'galaxy',
    weekday => 'Sunday',
    hour    => 1,
    minute  => 10,
    require => File["${galaxy::params::backup_dir}/postgres"],
  }

  cron {'postgres dump galaxytools':
    ensure  => 'present',
    command => "/usr/bin/pg_dump galaxytools > ${galaxy::params::backup_dir}/postgres/galaxytools.sql",
    user    => 'galaxy',
    weekday => 'Sunday',
    hour    => 1,
    minute  => 15,
    require => File["${galaxy::params::backup_dir}/postgres"],
  }

  file { "${galaxy::params::backup_dir}/config":
    ensure => 'directory',
    owner  => 'galaxy',
    group  => 'galaxy',
  }

  cron {'backup config':
    ensure  => 'present',
    command => "cp ${directory}/config/*.xml ${galaxy::params::backup_dir}/config/",
    user    => 'galaxy',
    weekday => 'Sunday',
    hour    => 1,
    minute  => 20,
    require => File["${galaxy::params::backup_dir}/config"],
  }

}
