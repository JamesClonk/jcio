#!/bin/bash
set -e
set -u

if [ $# -ne 1 ]; then
	echo "usage: $0 <FQDN>"
	exit 1
fi

HOST=$1
SUBJ="/C=CH/ST=Bern/L=Bern/O=jamesclonk.io/OU=webdev/CN=${HOST}"
PASSWORD=$(openssl rand -base64 32)

mkdir ${HOST}
cd ${HOST}
trap "cd ..; exit 1" INT TERM EXIT

# generate certificates
echo "create server keys"
openssl genrsa -passout pass:${PASSWORD} -aes256 -out ca-key.pem 2048
openssl req -passin pass:${PASSWORD} -new -x509 -days 3650 -key ca-key.pem -sha256 -out ca.pem -subj ${SUBJ}
openssl genrsa -out server-key.pem 2048
openssl req -new -key server-key.pem -out server.csr -subj ${SUBJ} 
openssl x509 -passin pass:${PASSWORD} -req -days 3650 -in server.csr -CA ca.pem -CAkey ca-key.pem \
    -CAcreateserial -out server-cert.pem

echo "create client keys"
openssl genrsa -out key.pem 2048
openssl req -subj '/CN=client' -new -key key.pem -out client.csr
echo "extendedKeyUsage = clientAuth" > extfile.cnf
openssl x509 -passin pass:${PASSWORD} -req -days 3650 -in client.csr -CA ca.pem -CAkey ca-key.pem \
    -CAcreateserial -out cert.pem -extfile extfile.cnf

echo "strip password from keys"
openssl rsa -in server-key.pem -out server-key.pem
openssl rsa -in key.pem -out key.pem

echo "remove files"
rm -v client.csr server.csr
rm -v extfile.cnf
rm -v ca.srl

echo "chmod keys"
chmod -v 400 ca-key.pem key.pem server-key.pem
chmod -v 440 ca.pem server-cert.pem cert.pem
chmod -v 750 .

echo ""
echo "certificates generated"
ls -l
echo ""

cd ..
