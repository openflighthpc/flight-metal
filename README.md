# README

## Install

This app can be installed via:
```
git clone https://github.com/alces-software/flight-metal
cd flight-metal 
bundle install
```

## Run

The app can be ran by:
```
bin/flight-metal --help # Gives the main help page
```

## Usage

Flight `metal` manages the following stages of a cluster deployment:
1. Imports/Caches/Manages basic cluster configurations,
2. Hunts for node's MAC addresses,
3. Partially manages DHCP configuration,
4. Manages the build process, and
5. Preforms `ipmi` and `power` related commands

### Configuration Management
#### Getting Started with Import

`metal` is designed to seamlessly integrate within the _openFlightHPC_ ecosystem and can directly import cluster configurations. For this section, you will need a flight `manifest` and associated build files. Read further on how to configure cluster components manually without a `manifest`.

The `import` command will cache the configurations/files from the manifest into the cluster. It is recommended that each import is into a new cluster with the `--init` flag.

```
> metal import <path to manifest> --init <new cluster identifier>
```

If your `manifest` contains a fully configured cluster, then you are ready to skip to hunting MAC address. Please see the following steps if further configuration is required.

#### Getting Started without Import

A new blank cluster can be created with the `init-cluster` command. It will prompt you for the required parameters and switch to the cluster. Don't worry if you do this by mistake, it is possible to `import` configurations at a later date.

```
# Creates and switches to the new cluster
> metal init-cluster <new cluster identifier>
```

#### Import (Advanced)

The `import` command is used to copy cluster configurations from an _openFlightHPC_ `manifest`. By default it only imports missing nodes into the current cluster.

The `--force` flag is used to update BOTH the cluster and nodes configuration. This action may change the default configuration of the cluster.

```
> metal init-cluster foo

# Imports the nodes configuration only
> metal import path/to/manifest


# NOOP: The nodes have already been imported
> metal import path/to/manifest

# Force updates the cluster and nodes configuration
> metal import path/to/manifest --force

# NOTE: Using --force with --init (Not Recommened)
# Will switch to and force update the cluster specified by --init even if the
# cluster already exists
> metal import path/to/cluster --force --init bar
```

#### Creating, Editing, and Deleting Configurations

The adding and editing of `clusters` and `nodes` use a similar mechanism. All the following commands will open the configuration file in your terminal editor. The editor is set by the `$VISUAL` or `$EDITOR` env vars. The available fields will be documented in the editor.

*NOTE*: All the following commands can be script non-interactively using the `--fields` flag. See command help for further details.

A new cluster can be created with `init-cluster` command. This will create and switch to the new cluster. The cluster identifier has to be unique but does not need to match the domain name given in the `manifest`.

New nodes are added to the cluster using the `create` command. It will take the path to the `pxelinux` and `kickstart` files along with the other configuration values. The configuration files can be updated after the fact, but this is only opportunity to set the build files.

Nodes can be removed using the `delete` command, which will remove the configuration and build files from the cache. Existing node and cluster configurations can be updated using the `edit-cluster` and `edit` commands respectively.

```
# Create and configure the cluster details
> metal init-cluster bar

# Edit the current ('bar') cluster details
> metal edit-cluster

# Add and configure a new node
> metal create node01

# Edit the node
> metal edit node01

# Delete the node
> metal detete node01
```

#### Switching and Listing

A full list of existing cluster can be retrieved using the `list-clusters` command. Then the current cluster can be changed using `switch-cluster`:

```
# Creates the inital clusters and switches to bar
> metal init-cluster foo
> metal init-cluster bar

# Lists the foo and bar clusters:
> metal list-clusters

# Switches back to the foo cluster
> metal switch-cluster foo
```

The full details of the configured nodes can be retrieved with the `list` command. This will include the list of nodes and their configuration properties:

```
# View the details of all the nodes
> metal list
```

# License
Eclipse Public License 2.0, see LICENSE.txt for details.

Copyright (C) 2019-present Alces Flight Ltd.

This program and the accompanying materials are made available under the terms of the Eclipse Public License 2.0 which is available at https://www.eclipse.org/legal/epl-2.0, or alternative license terms made available by Alces Flight Ltd - please direct inquiries about licensing to licensing@alces-flight.com.

flight-metal is distributed in the hope that it will be useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more details.


