# == Class: galaxy::directorystructure
#
# This class sets up the basic directory structure for mounting project directories
# and mounts the galaxy project directory.
#
# === Examples
#
#  include galaxy::directorystructure
#
# === Authors
#
# Sarah Diehl <sarah.diehl@uni.lu>
#
# === Copyright
#
# Copyright 2015 Sarah Diehl
#

class galaxy::directorystructure inherits galaxy::params {

  # Set up basic structure
  file { $galaxy::params::work_dir:
    ensure => 'directory',
  }
  file { $galaxy::params::projects_dir:
    ensure => 'directory',
  }

  file { $galaxy::params::mount_point:
    ensure => 'directory',
  }

  # Galaxy project directory
  file { "${galaxy::params::projects_dir}/galaxy":
    ensure  => 'directory',
    require => File[$galaxy::params::projects_dir]
  }

  mount { "${galaxy::params::projects_dir}/galaxy":
    device  => "${galaxy::params::nfs2}/galaxy",
    fstype  => 'nfs',
    ensure  => 'mounted',
    options => $galaxy::params::nfs_options,
    atboot  => true,
    require => File["${galaxy::params::projects_dir}/galaxy"],
  }
}
