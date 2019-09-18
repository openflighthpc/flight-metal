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
2. Hunts for node's MAC addresses and DHCP entries,
3. Manages the build process, and
4. Preforms `ipmi` and `power` related commands

### Getting Started

The following will create a new cluster with three basic nodes and three gpus nodes:

```
# Create a new cluster configuration
> metal cluster create foo

# Create the first three nodes
> metal node create node1 FF:FF:FF:FF:FF:01
> metal node create node2 FF:FF:FF:FF:FF:02
> metal node create node3 FF:FF:FF:FF:FF:03

> metal node create gpu1 FF:FF:FF:FF:FF:04
> metal node create gpu2 FF:FF:FF:FF:FF:05
> metal node create gpu3 FF:FF:FF:FF:FF:06
```

Next add the nodes to the relevant primary group

```
> metal group nodes add nodes node1 node2 node03 gpu1 gpu2 gpu3
> metal group nodes add gpus gpu1 gpu2 gpu3
```

Now the `pxelinux`, `kickstart`, and `dhcp` files need to created. The following will create the `pxelinux` files manually by opening them in the editor.

```
> metal node file touch node1 pxelinux
> metal node file touch node2 pxelinux
> metal node file touch node3 pxelinux

> metal node file edit node1 pxelinux
> metal node file edit node2 pxelinux
> metal node file edit node3 pxelinux
```

Alternatively they can render based on a cluster level template.

```
> metal cluster node-template edit kickstart

# Render the nodes individually
> metal node file update node1 kickstart
> metal node file update node2 kickstart
...

```

#### Getting Started with Import

TBA


#### Switching and Listing

A full list of existing cluster can be retrieved using the `list-clusters` command. Then the current cluster can be changed using `switch-cluster`:

```
# Creates the inital clusters and switches to bar
> metal cluster create foo
> metal cluster create bar

# Lists the foo and bar clusters:
> metal clusters list

# Switches back to the foo cluster
> metal cluster switch foo
```

The full details of the configured nodes can be retrieved with the `list` command. This will include the list of nodes and their configuration properties:

```
# View the important details about the nodes
> metal node list
```

### The rendering system

TBA

### Building the nodes

Fully configured nodes added using the `build` command without any arguments. Nodes will automatically be built if they have a MAC address and the `rebuild` flag has been set.

Nodes default to the `rebuild` state when they are initially created unless explicitly stated to the contrary. Turning off the rebuild flag will permanently prevent the node from building.

The build process will automatically place the `kickstart` and `pxelinux` files into their corresponding system locations. Existing system files will not be replaced by `build` and instead an warning will be raised. It is assumed that the existing files are from a currently running build, and should not be replaced. The files will be removed when each node reports back as complete.

After setting up the build files, `metal` will listen on UDP port 24680 (configurable in main config) for nodes to report back. The complete message must include it's `node` name and `built` flag in `JSON` syntax: `{ "node" : <name>, "built" : true }`

# License
Eclipse Public License 2.0, see LICENSE.txt for details.

Copyright (C) 2019-present Alces Flight Ltd.

This program and the accompanying materials are made available under the terms of the Eclipse Public License 2.0 which is available at https://www.eclipse.org/legal/epl-2.0, or alternative license terms made available by Alces Flight Ltd - please direct inquiries about licensing to licensing@alces-flight.com.

flight-metal is distributed in the hope that it will be useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more details.


