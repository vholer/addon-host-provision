.. _ddc_usage:

===========
Basic Usage
===========

Operations with the physical resources are performed using the installed ``oneprovision`` tool. Create a new provision, manage (reboot, reset, power off, resume) the existing provisions, and delete the provision at the end. The user experience is very same as you know from other OpenNebula CLI tools.

Commands
========

This section covers available commands of the ``oneprovision`` tool.

.. note::

    Additional CLI arguments ``--verbose/-d`` and ``--debug/-D`` (applicable for all commands of ``oneprovision`` tool) provide additional levels of logging. Check :ref:`Logging Modes <ddc_usage_log>` for detailed description.

Create
------

Deployment of new physical resources is a 3 steps process:

1. :ref:`Provision <ddc_provision>`. Resources are allocated on the remote provider (e.g. use provider's API to get a clean new host).
2. :ref:`Configuration <ddc_config_overview>`. Resources are reconfigured for the particular use (e.g. install virtualization tools on a new host).
3. **Use**. Ready-to-use resources are added into the OpenNebula as (virtualization) hosts and enabled.

All steps are covered by single run of the command ``oneprovision create``, it's necessary to provide :ref:`provision template <ddc_provision_template>` (with information about requested physical resources and how to configure the software on them) and OpenNebula host monitoring/virtualization drivers. The OpenNebula provision ID (which is in fact also the OpenNebula host ID) is returned after successful provision.

Example:

.. prompt:: bash $ auto

    $ oneprovision create provision.yaml -v kvm -i kvm -d
    WARNING: This operation can take tens of minutes. Please be patient.
    2018-06-14 10:31:38 INFO  : Deploying
    2018-06-14 10:36:06 INFO  : Creating OpenNebula host
    2018-06-14 10:36:06 INFO  : Monitoring host
    2018-06-14 10:36:11 INFO  : Checking working SSH connection
    2018-06-14 10:36:15 INFO  : Configuring hosts
    ID: 0

The required parameters:

* ``FILENAME``: file with :ref:`provision template<ddc_provision_template>`
* ``--im/-i``: host Information Manager driver
* ``--vm/-v``: host Virtual Machine Manager driver
* ``--cluster/-c``: cluster ID/name to add host (default: 0)

The optional parameters:

* ``--ping-retries``: number of SSH connection retries (default: 10)
* ``--ping-timeout``: seconds between each SSH connection retry (default: 20)

List
----

The ``list`` command lists all provisions, and ``top`` command periodically refreshes the list until it's terminated.

.. prompt:: bash $ auto

    $ oneprovision list
      ID NAME            CLUSTER   RVM PROVIDER VM_MAD   STAT
       0 147.75.205.15   default     0 packet   kvm      on

    $ oneprovision top
    ...

Power Off
---------

The ``poweroff`` command offlines the host in the OpenNebula (making it unavailable for use by the users) and power off the physical resource.

.. prompt:: bash $ auto

    $ oneprovision poweroff 0 -d
    2018-06-14 12:02:17 INFO  : Powering off host: 0

Resume
------

The ``resume`` command power on the physical resource, and enables back the OpenNebula host (making it available again to the users).

.. prompt:: bash $ auto

    $ oneprovision resume 0 -d
    2018-06-14 12:04:54 INFO  : Resuming host: 0

Reboot
------

The ``reboot`` command offlines the OpenNebula host (making it unavailable for the users), cleanly reboots the physical resource and enables the OpenNebula host back (making it available again for the users after successful OpenNebula host monitoring).

.. prompt:: bash $ auto

    $ oneprovision reboot 0 -d
    2018-06-14 12:35:23 INFO  : Rebooting host: 0

Reset
-----

The ``reboot --hard`` command offlines the OpenNebula host (making it unavailable for the users), resets the physical resource and enables the OpenNebula host back.

.. prompt:: bash $ auto

    $ oneprovision reboot --hard 0 -d
    2018-06-14 12:35:48 INFO  : Resetting host: 0

SSH
---

The ``ssh`` command opens the interactive SSH connection on the physical resource to the same (privileged) user used for the configuration.

.. prompt:: bash $ auto

    $ oneprovision ssh 0
    Last login: Thu Jul 19 14:30:39 2018 from *****************
    [root@ip-172-30-4-47 ~]#

Additional argument may specify a command to run on the remote side.

.. prompt:: bash $ auto

    $ oneprovision ssh 0 hostname
    ip-172-30-4-47.ec2.internal

Configure
---------

The physical host :ref:`configuration <ddc_config_overview>` is part of the initial deployment, but it's possible to trigger the reconfiguration on provisioned host anytime later (e.g. when a configured service stopped running, or the host needs to be reconfigured different way). Based on the initially provided connection and configuration parameters in the :ref:`provision template <ddc_provision_template_configuration>`, the configuration steps are applied again.

.. warning::

    It's important to understand that the (re)configuration can happen only on physical hosts that aren't actively used by the users (e.g., no virtual machines running on the host) and with the OS/services configuration untouched since the last (re)configuration. It's not possible to (re)configure the host with manually modified OS/services configuration. It's not possible to fix a seriously broken host. Such situation needs to be manually handled by the experienced systems administrator.

The ``configure`` command offlines the OpenNebula host (making it unavailable for the users) and triggers again the deployment configuration phase. If provisioned the host was already successfully configured before, the command line argument ``--force`` needs to be used. After successful configuration, the OpenNebula host is enabled back.

.. prompt:: bash $ auto

    $ oneprovision configure 0 -d
    ERROR: Host is already configured

    $ oneprovision configure 0 -d --force
    2018-06-14 13:04:23 INFO  : Checking working SSH connection
    2018-06-14 13:04:27 INFO  : Configuring hosts

Delete
------

The ``delete`` command releases the physical resources to the remote provider and deletes the host in the OpenNebula.

.. prompt:: bash $ auto

    $ oneprovision delete 0 -d
    2018-06-14 13:08:55 INFO  : Deleting host: 0

.. _ddc_usage_log:

Logging Modes
=============

The ``oneprovision`` tool in the default mode returns only minimal requested output (e.g., provision IDs after create), or errors. The operations with the remote providers or the host configuration are complicated and time-consuming tasks. For the better insight and for debugging purposes there are 2 logging modes available providing more information on the standard error output.

* **verbose** (``--verbose/-d``). Only main steps are logged.

Example:

.. prompt:: bash $ auto

    $ oneprovision reboot 0 -d
    2018-06-14 14:36:29 INFO  : Rebooting host: 0

* **debug** (``--debug/-D``). All internal actions incl. generated configurations with **sensitive data** are logged.

Example:

.. prompt:: bash $ auto

    $ oneprovision reboot 0 -D
    2018-06-14 14:37:33 DEBUG : Offlining OpenNebula host: 0
    2018-06-14 14:37:33 INFO  : Rebooting host: 0
    2018-06-14 14:37:33 DEBUG : Command run: /var/lib/one/remotes/pm/packet/reboot c4b5c5f3-0ec0-4323-83b1-4c3324e0147a 147.75.33.123 0 147.75.33.123
    2018-06-14 14:37:40 DEBUG : Command succeeded
    2018-06-14 14:37:40 DEBUG : Enabling OpenNebula host: 0

Running Modes
=============

The ``oneprovision`` tool is ready to deal with common problems during the execution. It's able to retry some actions or clean up an uncomplete provision. Depending on where and how the tool is used, it offers 2 running modes:

* **interactive** (default). If the unexpected condition appears, the user is asked how to continue.

Example:

.. prompt:: bash $ auto

    $ oneprovision poweroff 0
    ERROR: Driver action '/var/lib/one/remotes/pm/packet/shutdown' failed
    Shutdown of Packet host 147.75.33.123 failed due to "{"errors"=>["Device must be powered on"]}"
    1. quit
    2. retry
    3. skip
    Choose failover method: 2
    ERROR: Driver action '/var/lib/one/remotes/pm/packet/shutdown' failed
    Shutdown of Packet host 147.75.33.123 failed due to "{"errors"=>["Device must be powered on"]}"
    1. quit
    2. retry
    3. skip
    Choose failover method: 1
    $

* **batch** (``--batch``). It's expected to be run as part of the scripts. No question is raised to the user, but the tool tries to automatically deal with the problem according to the failover method specified as a command line parameter:

+-------------------------+------------------------------------------------+
| Parameter               | Description                                    |
+=========================+================================================+
| ``--fail-quit``         | Set batch failover mode to quit (default)      |
+-------------------------+------------------------------------------------+
| ``--fail-retry`` number | Set batch failover mode to number of retries   |
+-------------------------+------------------------------------------------+
| ``--fail-cleanup``      | Set batch failover mode to clean up and quit   |
+-------------------------+------------------------------------------------+
| ``--fail-skip``         | Set batch failover mode to skip failing part   |
+-------------------------+------------------------------------------------+

Example of automatic retry:

.. prompt:: bash $ auto

    $ oneprovision poweroff 0 --batch --fail-retry 2
    ERROR: Driver action '/var/lib/one/remotes/pm/packet/shutdown' failed
    Shutdown of Packet host 147.75.33.123 failed due to "{"errors"=>["Device must be powered on"]}"
    ERROR: Driver action '/var/lib/one/remotes/pm/packet/shutdown' failed
    Shutdown of Packet host 147.75.33.123 failed due to "{"errors"=>["Device must be powered on"]}"
    ERROR: Driver action '/var/lib/one/remotes/pm/packet/shutdown' failed
    Shutdown of Packet host 147.75.33.123 failed due to "{"errors"=>["Device must be powered on"]}"

Example of non-interactive provision with automatic clean up in case of failure:

.. prompt:: bash $ auto

    $ oneprovision create provision.yaml -v kvm -i kvm -d --batch --fail-cleanup
    WARNING: This operation can take tens of minutes. Please be patient.
    2018-06-14 15:15:48 INFO  : Deploying
    2018-06-14 15:19:57 INFO  : Creating OpenNebula host
    2018-06-14 15:19:57 INFO  : Monitoring host: 0
    2018-06-14 15:20:08 INFO  : Checking working SSH connection
    2018-06-14 15:20:12 INFO  : Configuring hosts
    2018-06-14 15:21:33 WARN  : Command FAILED (code=): ANSIBLE_CONFIG=/tmp/d20180614-8478-1jhfx8n/ansible.cfg ansible-playbook --ssh-common-args='-o UserKnownHostsFile=/dev/null' -i /tmp/d20180614-8478-1jhfx8n/inventory -e @/tmp/d20180614-8478-1jhfx8n/group_vars/all /usr/share/one/oneprovision/ansible/site.yml
    ERROR: Configuration failed
    2018-06-14 15:21:33 INFO  : Deleting host: 0
