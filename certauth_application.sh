# CertAuth automatically creates a two-tier ecc certificate authority based on NSA Suite B's PKI requirements.
# by @lukasreinert


############
## Server ##
############


read -p "Enter absolute path of CA root directory [/root/ca]: " path
if [ "$path" == "" ]; then
    path="/root/ca"
fi
if [ ! -d "$path" ]; then
    echo "Path '$path' does not exist. Create a root CA first."
    exit 1
fi

read -p "Enter name of intermediate CA [intermediate]: " intermediate
if [ "$intermediate" == "" ]; then
    intermediate="intermediate"
fi
intermediate_path="$path/$intermediate"
if [ ! -f "$intermediate_path/openssl_$intermediate.conf" ]; then
    echo "Intermediate CA '$intermediate' does not exist. Check its name again or create one first."
    exit 1
fi

read -p "Set name for an application certificate [myapp]: " app
if [ "$app" == "" ]; then
    app="myapp"
fi
if [ -f "$intermediate_path/openssl_$app.conf" ]; then
    echo "Application certificate '$app' already exists. Choose a different name."
    exit 1
fi

read -p "Set subjectAltName [domain.tld]: " alt_name
if [ "$alt_name" == "" ]; then
    alt_name="domain.tld"
fi

cp $intermediate_path/openssl_$intermediate.conf $intermediate_path/openssl_$app.conf
sed -i "s@sed_domain@$alt_name@g" $intermediate_path/openssl_$app.conf

# create private key and certificate signing request
echo "Enter fields for $app certificate"
openssl req -config $intermediate_path/openssl_$app.conf -new -nodes -newkey ec:<(openssl ecparam -name secp384r1) -keyout $intermediate_path/private/$app.key.pem -out $intermediate_path/csr/$app.csr

# create certificate
openssl ca -config $intermediate_path/openssl_$app.conf -extensions server_cert -in $intermediate_path/csr/$app.csr -out $intermediate_path/certs/$app.crt.pem

cp $intermediate_path/certs/$app.crt.pem $intermediate_path/certs/$app.fullchain.crt.pem
cat $intermediate_path/certs/$intermediate.fullchain.crt.pem >> $intermediate_path/certs/$app.fullchain.crt.pem

echo "Application certificate '$app' has been successfully created."
