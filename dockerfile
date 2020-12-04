# a base image with httpd with logroate and other packages see apt-get
FROM docker-registry-dtna.app.corpintra.net/library/httpd:2.4.41-debian-10
user root
# setting proxies so we can get updates
ARG PROXY='http://appproxy.us164.corpintra.net' 
ARG PROXY_PORT='3128'
# now we are installing packages
RUN export http_proxy=${PROXY}:${PROXY_PORT} && \
	export https_proxy=${PROXY}:${PROXY_PORT} && \
	apt-get -y update && \
	apt-get -y install curl && \
	apt-get -y install unzip && \
	apt-get -y install logrotate && \
	apt-get -y install rpl && \
	apt-get clean all
ARG workspace='/tmp/ws'
RUN mkdir -p $workspace
WORKDIR $workspace
COPY . .
# stripping all windows characters
RUN sed -i 's/\r//g' *http*
# copying base httpd file, with proxy mods enabled and default port switched to 8080 from 80
RUN cp -f ./httpd.conf /usr/local/apache2/conf
# adding log rotate config
RUN mkdir -p /etc/logrotate.d/httpd && \
	mv $workspace/http_logrotate /etc/logrotate.d/httpd/ && \
	chmod -R 0644 /etc/logrotate.d
# copying file to set ulimits wasadmin
RUN cp ./limits.conf /etc/security/ --no-preserve=all
# adding group and IDs that will run apache and install the siteminder agent 
RUN groupadd -g 15669 wasadmin
RUN useradd -g 15669 -u 15669 wasadmin
# moving forward with pre-downloading the siteminder
# cleaning out the PID file, in case its left hanging
RUN rm -f /usr/local/apache2/logs/httpd.pid 
# carrying forward to the next image where app will be installed
CMD echo "base image is done"