# Hosting draw.io in your own web server

I did use draw.io for a while as a Wordpress plugin but it wasn't exactly the same as having a separate subdomain using it.

I wasn't sure what's the best way to set it up. First I though about using pages in my Gitlab instance but it seemed like little bit too much overhead.

In the end it was very easy:
1. Clone the git repo
2. configure a nginx vhost.

### Installation

Navigate to the directory where to clone the git repository:

`cd /var/www`

Clone the repository:

`git clone https://github.com/jgraph/draw.io.git`

Setup the nginx vhost. I use HTTPS. Both include files can be found here  
[secure_ssl.conf](https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/secure_ssl.conf)  
[restrictions.conf](https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/restrictions.conf)

This is the full vhost I use:

```
server {
        listen          80;
        # enforce https
        server_name     draw.example.com;
        location ~ .well-known/acme-challenge/ {
          root /var/www/letsencrypt;
          default_type text/plain;
        }
    location / {
        return 301 https://draw.example.com$request_uri;
    }
}

server {
        listen          443 ssl http2;
        listen          [::]:443 ssl http2;
        server_name     draw.example.com;
        root            /var/www/draw.example.com/public_html/draw.io/war;
        access_log      /var/www/log/draw.example_access.log;
        error_log       /var/www/log/draw.example_error.log warn;
        index           index.html;

        ssl                     on;
        ssl_certificate         /var/www/ssl/example.com/fullchain.pem;
        ssl_certificate_key     /var/www/ssl/example.com/privkey.pem;
        ssl_dhparam             /var/www/ssl/example_dhparams.pem;
        include                 global/secure_ssl.conf;
        include                 global/restrictions.conf;
        client_max_body_size    20M;
}

```
