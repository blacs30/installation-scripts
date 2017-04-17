# Create snakeoil certificates
This article covers the simple process of creating certificates for testing.
That is why they are called snakeoil as they should not be used for production because they don't provide any trust.

Anyway for testing it is helpful to use and they can be created offline. Letsencrypt offers testing certificates too but their service is only usable if the requesting machine is connected to the internet which might not be always the case.

It is basically just this script which creates the certificate and the key:  

```shell
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
-subj "/C=DE/ST=Some State/L=Some Place/CN=example.com/emailAddress=webmaster@example.com/O=My Corporation/OU=Org Unit 1/OU=Optional Org Unit 2" \
-keyout /etc/ssl/example.com.key \
-out /etc/ssl/example.com.crt
```

Change the parameter to your need:  
- C is the Country
- ST is the state
- L is the location / Place
- CN is the Common Name (your domain name)
- O is the Organization Name (eg, company)
- OU is the Organizational Unit Name (eg, section)
- emailAddress is the mail address that will appear in the certificate

After you've created the certificate set the correct and safe permissions to the key.  
`chmod 600 /etc/ssl/snakeoil.key`
