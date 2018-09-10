.. _ddc_config_overview:

========
Overview
========

Newly provisioned physical resources are (usually) running only a base operating system without any additional services. Hosts need to pass the configuration phase to configure the additional software repositories, install packages, and configure and run necessary services to comply with the intended host purpose. This configuration process is fully handled by the ``oneprovision`` tool as part of the initial deployment (``oneprovision create``) or independent run (``oneprovision configure``).

.. note::

    Tool ``oneprovision`` has a seamless integration with the `Ansible <https://www.ansible.com/>`__ (needs to be already installed on the system). It's not necessary to be familiar with the Ansible unless you need to make changes deep inside the configuration process.

As we use the Ansible for the host configuration, we'll also share its terminology.

* **task** - single configuration step (e.g. package installation, service start)
* **role** - set of related tasks (e.g. role to deal with Linux bridges - utils install, bridge configure, and activation)
* **playbook** - set of roles/tasks to configure several components at once (e.g. install services and configure the host as KVM hypervisor)

The configuration phase can be parameterized to slightly customize the configuration process (e.g. enable or disable particular OS feature, or force different repository location or version). These custom parameters are specified in the :ref:`configuration <ddc_provision_template>` section of the provision template. For most cases, the general defaults should match most requirements.

Detailed description of all roles and their configuration parameters is in separate chapter :ref:`Configuration Roles <ddc_config_roles>`, which is intended for advanced users.
