.. _ddc_configs_hostonly_nat:

==================================================
KVM host with host-only private networking and NAT
==================================================

This configuration prepares the host with

* KVM hypervisor
* bridge for the private host-only networking
* masquerade (NAT) to access the public services

.. important::

    If more physical hosts are created, the private traffic of the virtual machines isn't routed between them. Virtual machines on different hosts are isolated although sharing the same private address space!

Networking
==========

On the physical host, the IP configuration of prepared bridge ``br0`` (with TAP interface ``tap0``) is same on all hosts:

============= =================
Parameter     Value
============= =================
Interface     ``br0``
IP address    ``192.168.150.1``
Netmask       ``255.255.255.0``
============= =================

For **virtual machines**, the following IP configuration can be used:

============= =================
Parameter     Value
============= =================
IP address    any from range ``192.168.150.2 - 192.168.150.254``
Netmask       ``255.255.255.0``
Gateway (NAT) ``192.168.150.1``
============= =================

In the OpenNebula, the :ref:`virtual network <manage_vnets>` for the virtual machines can be defined by the following template:

.. code::

    NAME        = "private"
    VN_MAD      = "dummy"
    BRIDGE      = "br0"
    DNS         = "8.8.8.8 8.8.4.4"
    GATEWAY     = "192.168.150.1"
    DESCRIPTION = "Host-only networking with NAT"

    AR=[
        TYPE = "IP4",
        IP   = "192.168.150.2",
        SIZE = "253"
    ]

Put the template above into a file and execute the following command to create a virtual network:

.. code::

    $ onevnet create packet.tpl
    ID: 1

Parameters
==========

Main configuration parameters:

=====================================  ========================================== ===========
Parameter                              Value                                      Description
=====================================  ========================================== ===========
``bridged_networking_static_ip``       192.168.150.1                              IP address of the bridge
``bridged_networking_static_netmask``  255.255.255.0                              Netmask of the bridge
``opennebula_node_kvm_use_ev``         **True** or False                          Whether to use the ev package for kvm
``opennebula_node_kvm_param_nested``   True or **False**                          Enable nested KVM virtualization
``opennebula_repository_version``      5.6                                        OpenNebula repository version
``opennebula_repository_base``         ``https://downloads.opennebula.org/repo/`` Repository of the OpenNebula packages
                                       ``{{ opennebula_repository_version }}``
=====================================  ========================================== ===========

All parameters are covered in the :ref:`Configuration Roles <ddc_config_roles>`

Configuration Steps
===================

The roles and tasks are applied during the configuration in the following order:

1. **python** - check and install Python required for Ansible
2. **ddc** - general asserts and cleanups
3. **opennebula-repository** - setup OpenNebula package repository
4. **opennebula-node-kvm** - install OpenNebula node KVM package
5. **opennebula-ssh** - deploy local SSH keys for the remote oneadmin
6. **tuntap** - create TAP ``tap0`` interface
7. **bridged-networking** - bridge Linux bridge ``br0`` with TAP interface
8. **iptables** - create basic iptables rules and enable NAT

with the following configuration overrides to the :ref:`roles defaults <ddc_config_roles>`:

=================================== =====
Parameter                           Value
=================================== =====
``opennebula_node_kvm_use_ev``      true
``bridged_networking_iface``        tap0
``bridged_networking_iface_manage`` false
``bridged_networking_static_ip``    192.168.150.1
``iptables_masquerade_enabled``     true
``iptables_base_rules_strict``      false
=================================== =====
