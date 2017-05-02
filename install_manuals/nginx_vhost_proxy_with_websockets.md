# NGINX vhost configuration for a proxy setup with websockets

Background:  
I have a website using SSL which I want to access from many different places. In one of these places SSL is only possible via port 443 but I can have this page only running on a different port as 443 is blocked with another more important application.   

Workaround:  
The solution for me is to have an NGINX vhost with a proxy setup on the default 443 port, it is running on a different server so it is possible. The proxy URL is my SSL page running on 6443. The page makes usage ob websockets and I also want to use that, both of the proxy upgrade header make that possible. It's a simple vhost which helps me alot.

Both include files can be found here  
[secure_ssl.conf](https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/secure_ssl.conf)  
[restrictions.conf](https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/restrictions.conf)  

```
upstream backend {

	least_conn;
	server target.domain.com:6443 fail_timeout=3;
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name ssl.domain.com;
	access_log /var/www/log/domain.com_access.log;
	error_log /var/www/log/domain.com_error.log;

	ssl on;
	ssl_certificate /var/www/ssl/domain.com/fullchain.pem;
	ssl_certificate_key /var/www/ssl/domain.com/privkey.pem;
	ssl_dhparam /var/www/ssl/domain.com_dhparams.pem;

	include global/secure_ssl.conf;
	include global/restrictions.conf;


	# This block is for GEOIP blocking / allowing
	# if ($allow_visit = no) {
	#    return 403;
	# }

	location / {
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_read_timeout 86400;
		proxy_pass https://backend;
		proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;
	}
}
```
