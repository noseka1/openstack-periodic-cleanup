# openstack-periodic-cleanup

Using OpenStack Mitaka we realized that OpenStack didn't clean up resources properly and they were piling up. We have seen diverse OpenStack database tables growing infinitely.  We have experienced Neutron leaving processes running on the controller nodes, leaving empty network namespaces behind or filling up the `/var/log/neutron` directory with files. 

To address the resource leaks, we wrote this set of clean-up scripts. You can use them *at your own risk*. 
