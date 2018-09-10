.. _ddc_provision:

=========
Provision
=========

The provision is a process of allocating new physical resources from the remote providers. :ref:`Provision drivers <ddc_driver>` are used for communication with the remote providers. Credentials for the communication and parameters of the required provision (hardware, operating system, IPs, etc.) need to be specified. All these information are stored in the :ref:`provision template <ddc_provision_template>` file and passed to the ``oneprovision create`` command.

In this chapter, we'll describe the format and content of the provision template.

.. _ddc_provision_template:

Template
========

**Provision template** is a YAML formatted file with parameters specifying the new physical resources to be provisioned. Contains:

* global default parameters for

  * remote connection (SSH),
  * host provision driver,
  * host configuration tunables,

* list of hosts to deploy with overrides to the global defaults above.

.. warning::

    Only 1 host can be listed in the provision template for now.

Example:

.. code::

    ---

    # Global defaults:
    connection:
      public_key: '/var/lib/one/.ssh/id_rsa.pub'
      private_key: '/var/lib/one/.ssh/id_rsa'

    provision:
      driver: "packet"
      packet_token: "********************************"
      packet_project: "************************************"
      facility: "ams1"
      plan: "baremetal_0"
      billing_cycle: "hourly"
      os: "ubuntu_16_04"

    configuration:
      opennebula_node_kvm_param_nested: true

    # List of devices with connection/provision/configuration overrides:
    devices:
      - connection:
          public_key: '/var/lib/one/.ssh/ddc/id_rsa.pub'
          private_key: '/var/lib/one/.ssh/ddc/id_rsa'

        provision:
          hostname: "kvm-host001.priv.ams1"
          os: "centos_7"

        configuration:
          opennebula_node_kvm_param_nested: false

.. _ddc_provision_template_connection:

Section "connection"
--------------------

This section contains parameters for the remote SSH connection on the privileged user (or, the user with escalation rights via ``sudo``) of the newly provisioned host(s).

+-----------------+--------------------------------------+-------------------------------------------+
| Parameter       | Default                              | Description                               |
+=================+======================================+===========================================+
| ``remote_user`` | ``root``                             | Remote user to connect via SSH.           |
+-----------------+--------------------------------------+-------------------------------------------+
| ``remote_port`` | ``22``                               | Remote SSH service port.                  |
+-----------------+--------------------------------------+-------------------------------------------+
| ``public_key``  | ``/var/lib/one/.ssh/ddc/id_rsa.pub`` | Path or content of the SSH public key.    |
+-----------------+--------------------------------------+-------------------------------------------+
| ``private_key`` | ``/var/lib/one/.ssh/ddc/id_rsa``     | Path or content of the SSH private key.   |
+-----------------+--------------------------------------+-------------------------------------------+

.. _ddc_provision_template_provision:

Section "provision"
-------------------

This section contains parameters for the provisioning driver. Most parameters are specific for each driver, the only valid common parameters are:

+-----------------+--------------------------------------+-------------------------------------------+
| Parameter       | Default                              | Description                               |
+=================+======================================+===========================================+
| ``driver``      | none, needs to be specified          | Host provision driver.                    |
|                 |                                      | Supported values: ``packet``, ``ec2``     |
+-----------------+--------------------------------------+-------------------------------------------+

Please, see the driver specific pages with the parameters:

* :ref:`Packet <ddc_driver_packet_params>`
* :ref:`Amazon EC2 <ddc_driver_ec2_params>`

.. _ddc_provision_template_configuration:

Section "configuration"
-----------------------

This section provides parameters for the host configuration process (e.g. KVM installation, host networking etc.). All parameters are passed to the external configuration tool (Ansible), all available parameters are covered by :ref:`configuration <ddc_config_roles>` chapter.

.. _ddc_provision_template_devices:

Section "devices"
-----------------

.. warning::

    Only 1 host can be listed in the provision template for now.

In this section, you must define each physical host you want to deploy. Hosts are defined as a structure with similar (optional) sections **connection**, **provision**, and **configuration** as global defaults above. The parameters in these sections override the parameters from the global sections.
