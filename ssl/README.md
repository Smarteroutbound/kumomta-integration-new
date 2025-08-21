# SSL Certificates Directory

Place your SSL certificates here for nginx SSL termination.

## Required Files:
- `cert.pem` - Your SSL certificate
- `key.pem` - Your private key

## Example:
```bash
# Copy your certificates here
cp /path/to/your/cert.pem ./ssl/cert.pem
cp /path/to/your/key.pem ./ssl/key.pem
```

## Note:
For development/testing, you can use self-signed certificates or leave this empty.
The nginx container will start without SSL if no certificates are present.
