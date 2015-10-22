# == Class: galaxy::params
#
# Default parameters for the galaxy puppet package.
#
# === Authors
#
# Sarah Diehl <sarah.diehl@uni.lu>
#
# === Copyright
#
# Copyright 2015 Sarah Diehl
#

class galaxy::params {

  $branch              = 'master'
  $repository          = 'git://github.com/diehlsa/galaxy-ulhpc.git'
  $directory           = '/home/galaxy/galaxy-dist'
  $postgresql_password = 'changeme'
  $id_secret           = 'SECURE ID SECRET'

  $mount_point     = '/mnt/nfs'
  $work_dir        = '/work'
  $projects_dir    = "${work_dir}/projects"
  $nfs1            = 'nfs.gaia-cluster.uni.lux:/export/projects'
  $nfs2            = '10.79.1.6:/export/projects'
  $nfs_options     = 'async,defaults,auto,nfsvers=3,tcp'

  $galaxy_data_dir = "${projects_dir}/galaxy/internal"
  $backup_dir      = "${projects_dir}/galaxy/internal/backup"

}
