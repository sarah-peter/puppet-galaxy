# galaxy

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with galaxy](#setup)
    * [What galaxy affects](#what-galaxy-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with galaxy](#beginning-with-galaxy)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)

## Overview

This module sets up a Galaxy server according to the specific requirements of the University of Luxembourg's HPC group and the LCSB.

So far it only works on Debian wheezy.

This is **not** a generally applicable puppet module that can be used as is. It contains a lot of very specific settings  for the ULHPC cluster environment. Please regard it rather as a documentation of the steps to set up a production Galaxy server.

## Module Description

The module sets up a Galaxy server with four load-balanced web servers and four job runners. It uses Apache2 as a proxy server and a PostGreSQL database.

## Setup

### What galaxy affects

* creates 'galaxy' user and group
* PostGreSQL: creates 'galaxy' and 'galaxytools' databases with user 'galaxy' as the owner
* Apache2: creates a virtual host
* /etc/init.d/galaxy
* packages: installs gcc, python, mercurial, tar and openssl

### Setup Requirements

This module depends on 

* [puppetlabs/apache](https://forge.puppetlabs.com/puppetlabs/apache)
* [puppetlabs/postgresql](https://forge.puppetlabs.com/puppetlabs/postgresql)
* [puppetlabs/vcsrepo](https://forge.puppetlabs.com/puppetlabs/vcsrepo)

### Beginning with galaxy

For a simple standard setup just set the postgresql_password to a secure password:
	
	class { 'galaxy':
	  postgresql_password => 'securepassword',
	}


## Usage

It suffices to declare the `galaxy` class, everything else is automatically included. The `$postgresql_password` should definitely be changed for a production server, as well as the `$id_secret`. The `$directory` is fine with the default setting.

## Reference

### Class: `galaxy`
Does all the work.

### Class: `galaxy::params`
This class sets the default parameters for the Galaxy puppet module.

### Class: `galaxy::directorystructure`
This class sets up the directory structure for the project directories and mounts the galaxy project directory.

### Defined Type: `galaxy::projectmount`
This defined resource type mounts a project directory read-only.

## Limitations

Only tested on Debian wheezy.