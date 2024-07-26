# CertAuth automatically creates a two-tier ecc certificate authority based on NSA Suite B's PKI requirements.
# by @lukasreinert 


##################
## Intermediate ##
##################


read -p "Enter absolute path of CA root directory [/root/ca]: " path
if [ "$path" == "" ]; then
    path="/root/ca"
fi
if [ ! -d "$path" ]; then
    echo "Path '$path' does not exist. Create a root CA first."
    exit 1
fi

read -p "Enter name of root CA [root]: " root
if [ "$root" == "" ]; then
    root="root"
fi
if [ ! -f "$path/openssl_$root.conf" ]; then
    echo "Root CA '$root' does not exist. Check its name again."
    exit 1
fi

read -p "Set name for intermediate CA [intermediate]: " intermediate
if [ "$intermediate" == "" ]; then
    intermediate="intermediate"
fi
if [ -d "$path/$intermediate" ]; then
    echo "Intermediate CA '$intermediate' already exists. Choose a different name."
    exit 1
fi

read -p "Set intermediate CA default_days [365]: " default_days
if [ "$default_days" == "" ]; then
    default_days="365"
fi

read -p "Set intermediate CA default_crl_days [7]: " default_crl_days
if [ "$default_crl_days" == "" ]; then
    default_crl_days="3"
fi

read -p "Set CRL url for intermediate CA [https://crl.domain.tld/intermediate/revocation.crl]: " crl_url
if [ "$crl_url" == "" ]; then
    crl_url="https://crl.domain.tld/intermediate/revocation.crl"
fi

read -p "Set OSCP certificate url for intermediate CA [https://ocsp.domain.tld/intermediate/ocsp.crt]: " ocsp_cert_url
if [ "$ocsp_cert_url" == "" ]; then
    ocsp_cert_url="https://ocsp.domain.tld/intermediate/ocsp.crt"
fi

read -p "Set OSCP url for intermediate CA [https://ocsp.domain.tld/intermediate/]: " ocsp_url
if [ "$ocsp_url" == "" ]; then
    ocsp_url="https://ocsp.domain.tld/intermediate/"
fi
intermediate_path="$path/$intermediate"

# create intermediate ca directory structure
mkdir -p $intermediate_path/certs $intermediate_path/crl $intermediate_path/csr $intermediate_path/private
touch $intermediate_path/index.txt
echo 1000 > $intermediate_path/serial
echo 1000 > $intermediate_path/crlnumber
cp $path/openssl_template.conf $intermediate_path/openssl_template.conf
cp $path/certauth_revoke_template.sh $intermediate_path/certauth_revoke_template.sh
cp $path/certauth_crl_template.sh $intermediate_path/certauth_crl_template.sh

cp $intermediate_path/openssl_template.conf $intermediate_path/openssl_$intermediate.conf
sed -i "s@sed_dir@$intermediate_path@g" $intermediate_path/openssl_$intermediate.conf
sed -i "s@sed_crl_days@$default_crl_days@g" $intermediate_path/openssl_$intermediate.conf
sed -i "s@sed_default_days@$default_days@g" $intermediate_path/openssl_$intermediate.conf
sed -i "s@sed_v3_ca@v3_intermediate_ca@g" $intermediate_path/openssl_$intermediate.conf
sed -i "s@sed_policy@policy_loose@g" $intermediate_path/openssl_$intermediate.conf
sed -i "s@sed_crl_url@$crl_url@g" $intermediate_path/openssl_$intermediate.conf
sed -i "s@sed_ocsp_cert_url@$ocsp_cert_url@g" $intermediate_path/openssl_$intermediate.conf
sed -i "s@sed_ocsp_url@$ocsp_url@g" $intermediate_path/openssl_$intermediate.conf
cp $intermediate_path/openssl_$intermediate.conf $intermediate_path/openssl_template.conf
sed -i "s@sed_filename@$intermediate@g" $intermediate_path/openssl_$intermediate.conf

cp $intermediate_path/certauth_revoke_template.sh $intermediate_path/certauth_revoke.sh
chmod 744 $intermediate_path/certauth_revoke.sh
sed -i "s@sed_dir@$intermediate_path@g" $intermediate_path/certauth_revoke.sh
sed -i "s@sed_ca@$intermediate@g" $intermediate_path/certauth_revoke.sh

cp $intermediate_path/certauth_crl_template.sh $intermediate_path/certauth_crl.sh
chmod 700 $intermediate_path/certauth_crl.sh
sed -i "s@sed_dir@$intermediate_path@g" $intermediate_path/certauth_crl.sh
sed -i "s@sed_filename@$intermediate@g" $intermediate_path/certauth_crl.sh
read -p "Set intermediate CA key password: " password
if [ "$password" == "" ]; then
    exit 1
fi
sed -i "s@sed_password@$password@g" $intermediate_path/certauth_crl.sh

# create intermediate ca private key and certificate signing request
echo "Enter fields for $intermediate certificate"
openssl req -config $intermediate_path/openssl_$intermediate.conf -new -newkey ec:<(openssl ecparam -name secp384r1) -keyout $intermediate_path/private/$intermediate.key.pem -out $intermediate_path/csr/$intermediate.csr

# create intermediate ca certificate
openssl ca -config $path/openssl_$root.conf -extensions v3_intermediate_ca -md sha384 -in $intermediate_path/csr/$intermediate.csr -out $intermediate_path/certs/$intermediate.crt.pem

# create crl for intermediate ca
/bin/bash $intermediate_path/certauth_crl.sh

# add cronjob for crl
read -p "Adding a cronjob to automatically update the corresponding crl? [Y/n]: " crl_cron
if [ "$crl_cron" == "" ] || [ "$crl_cron" == "y" ] || [ "$crl_cron" == "Y" ]; then
    (crontab -l; echo ""; echo "0 3 * * * /bin/bash $intermediate_path/certauth_crl.sh"; echo "") | crontab -
fi

# add cronjob for crl
read -p "Adding a cronjob to automatically update crl to web? [Y/n]: " crl_web
if [ "$crl_web" == "" ] || [ "$crl_web" == "y" ] || [ "$crl_web" == "Y" ]; then
    read -p "Adding a cronjob to automatically update crl to web? [/var/www/ca/crl/$root]: " crl_web_path
    if [ "$crl_web_path" == "" ]; then
        crl_web_path="/var/www/ca/crl/$root"
    fi
    mkdir -p $crl_web_path
    (crontab -l; echo ""; echo "0 3 * * * /bin/bash $intermediate_path/certauth_crl.sh"; echo "") | crontab -
    (crontab -l; echo ""; echo "1 3 * * * cp $intermediate_path/crl/$intermediate.crl $crl_web_path/revocation.crl"; echo "") | crontab -
fi

# create ocsp key and certificate
echo "Creating OCSP for $intermediate"
openssl req -config $intermediate_path/openssl_$intermediate.conf -new -newkey ec:<(openssl ecparam -name secp384r1) -keyout $intermediate_path/private/ocsp.$intermediate.key.pem -out $intermediate_path/csr/ocsp.$intermediate.csr.pem -extensions server_cert
openssl ca -config $intermediate_path/openssl_$intermediate.conf -extensions ocsp -notext -md sha384 -in $intermediate_path/csr/ocsp.$intermediate.csr.pem -out $intermediate_path/certs/ocsp.$intermediate.crt.pem

sed -n '/BEGIN CERTIFICATE/,$p' $intermediate_path/certs/$intermediate.crt.pem > $intermediate_path/certs/$intermediate.fullchain.crt.pem
cat $path/certs/$root.crt.pem >> $intermediate_path/certs/$intermediate.fullchain.crt.pem

echo "Intermediate CA '$intermediate' has been successfully created."
