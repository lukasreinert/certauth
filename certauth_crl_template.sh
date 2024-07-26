# CertAuth automatically creates a two-tier ecc certificate authority based on NSA Suite B's PKI requirements.
# by @lukasreinert


#########
## CRL ##
#########


# generate crl
openssl ca -config sed_dir/openssl_sed_filename.conf -gencrl -out sed_dir/crl/sed_filename.crl.pem -passin "pass:sed_password"

# convert crl from pem to der format
openssl crl -in sed_dir/crl/sed_filename.crl.pem -out sed_dir/crl/sed_filename.crl -outform der
