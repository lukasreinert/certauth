# CertAuth automatically creates a two-tier ecc certificate authority based on NSA Suite B's PKI requirements.
# by @lukasreinert


##########
## Root ##
##########


read -p "Set absolute path for CA root directory [/root/ca]: " path
if [ "$path" == "" ]; then
    path="/root/ca"
fi
if [ -d "$path" ]; then
    echo "Path already exists. Remove the folder or use a different directory."
    exit 1
fi

read -p "Set name for root CA [root]: " root
if [ "$root" == "" ]; then
    root="root"
fi

read -p "Set root CA default_days [3650]: " default_days
if [ "$default_days" == "" ]; then
    default_days="3650"
fi

read -p "Set root CA default_crl_days [31]: " default_crl_days
if [ "$default_crl_days" == "" ]; then
    default_crl_days="31"
fi

read -p "Set CRL url for root CA [https://crl.domain.tld/root/revocation.crl]: " crl_url
if [ "$crl_url" == "" ]; then
    crl_url="https://crl.domain.tld/root/revocation.crl"
fi

read -p "Set OSCP certificate url for root CA [https://ocsp.domain.tld/root/ocsp.crt]: " ocsp_cert_url
if [ "$ocsp_cert_url" == "" ]; then
    ocsp_cert_url="https://ocsp.domain.tld/root/ocsp.crt"
fi

read -p "Set OSCP url for root CA [https://ocsp.domain.tld/root/]: " ocsp_url
if [ "$ocsp_url" == "" ]; then
    ocsp_url="https://ocsp.domain.tld/root/"
fi

# create root ca directory structure
mkdir -p $path/certs $path/crl $path/csr $path/private
touch $path/index.txt
echo 1000 > $path/serial
echo 1000 > $path/crlnumber
cp openssl_template.conf $path/openssl_template.conf
cp certauth_revoke_template.sh $path/certauth_revoke_template.sh
cp certauth_crl_template.sh $path/certauth_crl_template.sh

cp $path/openssl_template.conf $path/openssl_$root.conf
sed -i "s@sed_dir@$path@g" $path/openssl_$root.conf
sed -i "s@sed_filename@$root@g" $path/openssl_$root.conf
sed -i "s@sed_crl_days@$default_crl_days@g" $path/openssl_$root.conf
sed -i "s@sed_default_days@$default_days@g" $path/openssl_$root.conf
sed -i "s@sed_v3_ca@v3_ca@g" $path/openssl_$root.conf
sed -i "s@sed_policy@policy_strict@g" $path/openssl_$root.conf
sed -i "s@sed_crl_url@$crl_url@g" $path/openssl_$root.conf
sed -i "s@sed_ocsp_cert_url@$ocsp_cert_url@g" $path/openssl_$root.conf
sed -i "s@sed_ocsp_url@$ocsp_url@g" $path/openssl_$root.conf

cp $path/certauth_revoke_template.sh $path/certauth_revoke.sh
chmod 744 $path/certauth_revoke.sh
sed -i "s@sed_dir@$path@g" $path/certauth_revoke.sh
sed -i "s@sed_ca@$root@g" $path/certauth_revoke.sh

cp $path/certauth_crl_template.sh $path/certauth_crl.sh
chmod 700 $path/certauth_crl.sh
sed -i "s@sed_dir@$path@g" $path/certauth_crl.sh
sed -i "s@sed_filename@$root@g" $path/certauth_crl.sh
read -p "Set root CA key password: " password
if [ "$password" == "" ]; then
    exit 1
fi
sed -i "s@sed_password@$password@g" $path/certauth_crl.sh

# create root ca private key
echo "Enter fields for $root certificate"
openssl ecparam -genkey -name secp384r1 | openssl ec -aes256 -out $path/private/$root.key.pem

# create root ca certificate
openssl req -config $path/openssl_$root.conf -new -x509 -sha384 -days 9125 -extensions v3_ca -key $path/private/$root.key.pem -out $path/certs/$root.crt.pem

# create crl for root ca
/bin/bash $path/certauth_crl.sh

# add cronjob for crl
read -p "Adding a cronjob to automatically update the corresponding crl? [Y/n]: " crl_cron
if [ "$crl_cron" == "" ] || [ "$crl_cron" == "y" ] || [ "$crl_cron" == "Y" ]; then
    (crontab -l; echo ""; echo "0 3 * * * /bin/bash $path/certauth_crl.sh"; echo "") | crontab -
fi

# add cronjob for crl
read -p "Adding a cronjob to automatically update crl to web? [Y/n]: " crl_web
if [ "$crl_web" == "" ] || [ "$crl_web" == "y" ] || [ "$crl_web" == "Y" ]; then
    read -p "Adding a cronjob to automatically update crl to web? [/var/www/ca/crl/$root]: " crl_web_path
    if [ "$crl_web_path" == "" ]; then
        crl_web_path="/var/www/ca/crl/$root"
    fi
    mkdir -p $crl_web_path
    (crontab -l; echo ""; echo "0 3 * * * /bin/bash $path/certauth_crl.sh"; echo "") | crontab -
    (crontab -l; echo ""; echo "1 3 * * * cp $path/crl/$root.crl $crl_web_path/revocation.crl"; echo "") | crontab -
fi

# create ocsp key and certificate
echo "Creating OCSP for $intermediate"
openssl req -config $path/openssl_$root.conf -new -newkey ec:<(openssl ecparam -name secp384r1) -keyout $path/private/ocsp.$root.key.pem -out $path/csr/ocsp.$root.csr.pem -extensions server_cert
openssl ca -config $path/openssl_$root.conf -extensions ocsp -notext -md sha384 -in $path/csr/ocsp.$root.csr.pem -out $path/certs/ocsp.$root.crt.pem

echo "Root CA '$root' has been successfully created."
