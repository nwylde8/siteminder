**Base image of httpd plus several packages **

To be used as a base for all reverse proxies siteminder

Base includes:
	files from this repo copying to /tmp/ws
	downloading 4 packages via apt-get
	modifying base httpd to change group and port to 8080
	template silent install for siteminder agent, pointing to dev policy servers
	ulimits to wasadmin
	adding wasadmin user and group
	downloading CA binary to /tmp/ws
	
in the next image
handle siteminder install and configuration

	