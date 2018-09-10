.. _ddc_configs_overview:

========
Overview
========

Configurations are extensive descriptions of the configuration process (what and how is installed and configured on the physical host). Each configuration description prepares a physical host from the initial to the final ready-to-use state. Each description can configure the host in a completely different way (e.g. KVM host with private networking, KVM host with shared NFS filesystem, or KVM host supporting Packet elastic IPs, etc.). :ref:`Configuration parameters <ddc_provision_template>` are only a small tunables to the configuration process driven by the configurations.

Before the deployment, user must choose from the available configurations to apply on the host.

.. warning::

    Only 1 configuration is supported for now.
