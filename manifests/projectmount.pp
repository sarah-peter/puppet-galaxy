# == Defined type: galaxy::projectmount
#
# This defined resource type mounts a project directory read-only.
#
# === Parameters
#
# [*name*]
#   The title or name of the type needs to be exactly the same as the project
#   directory that should be mounted.
#
# === Examples
#
#  galaxy::projectmount { 'testproject': }
#
# === Authors
#
# Sarah Diehl <sarah.diehl@uni.lu>
#
# === Copyright
#
# Copyright 2015 Sarah Diehl
#

define galaxy::projectmount {
  include galaxy::params
  include galaxy::directorystructure

  file { "${galaxy::params::projects_dir}/${name}":
    ensure  => 'directory',
    require => Class['galaxy::directorystructure'],
  }

  mount { "${galaxy::params::projects_dir}/${name}":
    device  => "${galaxy::params::nfs2}/${name}",
    fstype  => 'nfs',
    ensure  => 'mounted',
    options => "${galaxy::params::nfs_options},ro",
    atboot  => 'true',
    require => File["${galaxy::params::projects_dir}/${name}"],
  }
}
