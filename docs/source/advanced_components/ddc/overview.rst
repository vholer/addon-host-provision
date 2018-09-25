.. _ddc_overview:

========
Overview
========

The aim of this prototype is to provide the tools and methods needed to grow your private cloud infrastructure with physical resources, initially individual hosts but eventually complete clusters, running on a remote bare-metal cloud providers.

Two of the use cases that will be supported by this new disaggregated cloud approach will be:

* **Distributed Cloud Computing**. This approach will allow the transition from centralized clouds to distributed edge-like cloud environments. You will be able to grow your private cloud with resources at edge data center locations to meet latency and bandwidth needs of your workload.
* **Hybrid Cloud Computing**. This approach works as an alternative to the existing hybrid cloud drivers. So there is a peak of demand and need for extra computing power you will be able to dynamically grow your underlying physical infrastructure. Compared with the use of hybrid drivers, this approach can be more efficient because it involves a single management layer. Also it is a simpler approach because you can continue using the existing OpenNebula images and templates. Moreover you always keep complete control over the infrastructure and avoid vendor lock-in.

.. image:: /images/ddc_overview.png
    :width: 50%
    :align: center

There are several benefits of this approach over the traditional, more decoupled hybrid solution that involves using the provider cloud API. However, one of them stands tall among the rest and it is the ability to move offline workload between your local and rented resources.

Features / limitations
======================

Supported IaaS providers:
  * EC2 (``i3.metal`` instance)
  * Packet

Deployment types:
  * deploy single physical host and add into existing cluster

Configuration types:
  * isolated KVM host configured with NAT

Version history
===============

* 5.6.0 (September 2018) - first prototype release
