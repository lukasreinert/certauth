# CertAuth automatically creates a two-tier ecc certificate authority based on NSA Suite B's PKI requirements.
# by @lukasreinert


##################
## Revoke Certs ##
##################


read -p "Which certificate do you want to revoke? [mycert]: " cert
if [ "$cert" == "" ]; then
    cert="mycert"
fi
if [ ! -f "sed_dir/certs/$cert.crt.pem" ]; then
    echo "Certificate '$cert' does not exists."
    exit 1
fi

openssl ca -revoke sed_dir/certs/$cert.crt.pem -config sed_dir/openssl_sed_ca.conf

/bin/bash sed_dir/certauth_crl.sh

if [ -f "sed_dir/certs/$cert.crt.pem" ]; then
    rm sed_dir/certs/$cert.crt.pem
fi

if [ -f "sed_dir/certs/$cert.fullchain.crt.pem" ]; then
    rm sed_dir/certs/$cert.fullchain.crt.pem
fi

if [ -f "sed_dir/private/$cert.key.pem" ]; then
    rm sed_dir/private/$cert.key.pem
fi
