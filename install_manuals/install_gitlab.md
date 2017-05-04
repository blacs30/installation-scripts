# Install Gitlab and configure it for an existing NGINX with HTTPS

The goal of this writing is to have an installation of Gitlab using an existing NGINX with HTTPS. The operating system is Debian 8.  

The installation of NGINX is not covered here, only the VHOST configuration.  

During my first setup of Gitlab I encountered 2 issues with the HTTPS configuration.
1. One issue was that I could not login anymore as soon I have set external_url to the https url (I had to set the http proxy flag to https in the VHOST configuration)  
2. I had set the https flag in the VHOST configuration but gravatar page was using HTTP instead of HTTPS (that was because I had set the external URL back to HTTP)

### Let's start

Install the gitlab repo with the script provided by gitlab:

`curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash`

Update apt  
`apt-get update`

Install the gitlab-ce package  
`apt-get -y install gitlab-ce`

Reconfigure gitlab, it starts gitlab as well  
`gitlab-ctl reconfigure`

Check the status of gitlab  
`gitlab-ctl status`


### Configure gitlab to your need  
Edit the file /etc/gitlab/gitlab.rb   

- adjust the external url, I use https  
  `external_url 'https://gitlab.example.com/'`
- for using your own webserver set the web_server external_users to the user which is running your nginx, here for debian it is www-data  
  `web_server['external_users'] = ['www-data']`
- as I want to use my existing nginx with an additional vhost disable the built-in nginx from gitlab   
  `nginx['enable'] = false`

This is just a simple setup but enough for me personally.
Don't forget to run `gitlab-ctl reconfigure` after editing the gitlab.rb file

### nginx vhost for gitlab
This is the vhost configuration which I use for my gitlab instance. It is very import if you want to use https for your gitlab to set the header `proxy_set_header X-Forwarded-Proto https`

```
upstream gitlab-workhorse {

	server unix:/var/opt/gitlab/gitlab-workhorse/socket;
}

server {

	listen 80;
	# enforce https
	server_name gitlab.example.com;
	location ~ .well-known/acme-challenge/ {

		root /var/www/letsencrypt;
		default_type text/plain;
	}

	location / {

		return 301 https://gitlab.example.com$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name gitlab.example.com;
	access_log /var/www/log/gitlab.example_access.log;
	error_log /var/www/log/gitlab.example_error.log warn;

	ssl on;
	ssl_certificate /var/www/ssl/example.com/fullchain.pem;
	ssl_certificate_key /var/www/ssl/example.com/privkey.pem;
	ssl_dhparam /var/www/ssl/example_dhparams.pem;
	include global/secure_ssl.conf;
	include global/restrictions.conf;
	client_max_body_size 20M;
	index index.php;

	# Additional rules go here.

	# This block is for GEOIP blocking / allowing
	# if ($allow_visit = no) {
	#    return 403;
	# }
	location / {

		## If you use HTTPS make sure you disable gzip compression
		## to be safe against BREACH attack.

		## https://github.com/gitlabhq/gitlabhq/issues/694
		## Some requests take more than 30 seconds.
		proxy_read_timeout 3600;
		proxy_connect_timeout 300;
		proxy_redirect off;
		proxy_http_version 1.1;

		proxy_set_header Host $http_host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header X-Forwarded-Proto https;

		proxy_pass http://gitlab-workhorse;
	}

	error_page 404 /404.html;
	error_page 422 /422.html;
	error_page 500 /500.html;
	error_page 502 /502.html;

	location ~ ^/(404|422|500|502)(-custom)?\.html$ {

		root /opt/gitlab/embedded/service/gitlab-rails/public;
		internal;
	}
}
```

### Sources  
https://www.howtoforge.com/tutorial/how-to-install-gitlab-on-debian-8/  
https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/settings/nginx.md  
https://gitlab.com/gitlab-org/gitlab-recipes/blob/master/web-server/nginx/gitlab-omnibus-nginx.conf  
