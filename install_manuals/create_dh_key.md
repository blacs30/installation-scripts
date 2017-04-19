# Create Diffie-Hellman key
Depending on which browser must be supported and which ssl ciphers and ssl protocols are used it is recommendet to create stronger Diffie-Hellman keys.

Mozilla has a nice generator for multiple webservers where ssl ciphers and other ssl settings are preconfigure: [mozilla.github.io](https://mozilla.github.io/server-side-tls/ssl-config-generator/)

Another helpful blog for nginx ssl configuration with some explanations is this one:[scaron.info](https://scaron.info/blog/improve-your-nginx-ssl-configuration.html)

Make also sure to test your website with qualys: [www.ssllabs.com](https://www.ssllabs.com/ssltest/)

Create a diffie hellman key with 2048 bit length, this will take a while:  
`openssl dhparam -out /etc/ssl/example.com_dhparams.pem 2048`

Set the read only permissions to the owner:  
`chmod 400 /etc/ssl/example.com_dhparams.pem`
