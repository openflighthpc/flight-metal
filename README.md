# README

## Install

This app can be installed via:
```
yum group install "Development Tools"
yum install libpcap-devel

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
> metal init-cluster foo

# Create the first three nodes
> metal create node1
> metal create node2
> metal create node3

> metal create gpu1
> metal create gpu2
> metal create gpu3
```

Next add the nodes to their relevant groups:

```
> metal update node1 groups=nodes
> metal update node2 groups=nodes
> metal update node3 groups=nodes

> metal update gpu1 groups=gpus,nodes
> metal update gpu2 groups=gpus,nodes
> metal update gpu3 groups=gpus,nodes
```

In order to build the nodes, they need a mac address and build files. The `metal hunt` command will collect the `mac` as the nodes pxeboot. Alternatively, the mac can be set using an update.

```
> metal hunt
Waiting for new nodes to appear on the network, please network boot them now...,
(Ctrl-C to terminate)
Detected a machine on the network (52:54:00:F2:DA:F0). Please enter the hostname:  |node1|
Saved node1 : ...

^CReceived Interrupt!

> metal update node2 mac=...
> metal update node3 mac=...
```

Now the `pxelinux`, `kickstart`, and `dhcp` files need to created. The following will create the `pxelinux` files manually by opening them in the editor. The `--touch` flag is only required when creating a new file, otherwise it is ignored

```
> metal edit node1 pxelinux --touch
> metal edit node2 pxelinux --touch
> metal edit node3 pxelinux --touch
```

Alternatively they can render based on a domain level template. The template must be created first using `metal edit`.

```
> metal edit domain kickstart --touch

# Render the nodes individually
> metal render node1 kickstart
> metal render node2 kickstart
...

# Render all the nodes (including the gpus)
> metal render --nodes-in nodes kickstart
```

Finally it is also possible to render nodes based on a particular group template

```
> metal edit --group nodes dhcp
# This will only render node[1-3] as the gpu's are not in the primary group
> metal render --primary-nodes-in nodes dhcp

# NOTE: The following command will render both node[1-3] and gpu[1-3]
#       The regular nodes will use the group template where the gpus will use the domain
> metal edit domain dhcp --touch
> metal render --nodes-in nodes dhcp
```

#### Getting Started with Import

TBA


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
# View the important details about the nodes
> metal list

# View all the details about the nodes
> metal list --verbose
```

### Collecting MAC Addresses and Updating DHCP
#### Hunting for MAC

There is a dedicated command for collecting MAC addresses of nodes: `hunt`. It works by listening out for `DHCP DISCOVER` messages on a network interface. The interface defaults to `eth0` but can be changed in the core application configuration file.
See: `etc/config.yaml.example` for how to set the `interface`

The `hunt` command only listens for `DHCP DISCOVER` where a Vendor Class Identifier has been set to `PXEClient`. When it has detected a valid discover, it will prompt for the node it should be assigned to. The `node` does not need to exist in order to `hunt` it, however this may cause issues with `import` as the node will now exist (as discussed above).

The `hunt` command can be exited by sending an `interrupt`. No other pxelinux configuration is required at this stage.

```
# Hunts for the nodes
> bin/metal hunt
Waiting for new nodes to appear on the network, please network boot them now...,
(Ctrl-C to terminate)

# After pxebooting a node
Detected a machine on the network (**:**:**:**:**:**). Please enter the hostname:  |node01|
...
```

The prompt will auto increment the suffix for each MAC address it does recognise. This is to allow new nodes to be added quickly by booting them in alphanumeric order. The prompt will preserve the name for existing MAC addresses. This prevents nodes from being renamed without explicitly setting it.

A MAC address can only be hunted once per call of the command. This filters out any spam from nodes that are stuck in a pxe boot loop. To re-hunt an existing node, the command must be called again.

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


