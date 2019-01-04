# Base files that are injected into the container

 * This directory gets mounted on /.bootstrap
 * The pod has /.bootstrap/setup.sh as the entrypoint

# Special cases

## Alpine
The setup will install Glibc for compatibility
