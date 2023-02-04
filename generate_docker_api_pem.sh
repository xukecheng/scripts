#!/bin/bash
# 
# -------------------------------------------------------------
# 自动创建 Docker TLS 证书
# -------------------------------------------------------------

IP=`curl ip.sb -4`

# Read the user input   

echo "Enter your password: "  
read password  
echo  
echo "Enter your country: "  
read country
echo
echo "Enter your state: "  
read state  
echo
echo "Enter your city: "  
read city  
echo
echo "Enter your organization: "  
read organization  
echo
echo "Enter your organizational_unit: "  
read organizational_unit  
echo
echo "Enter your email: "  
read email  
echo
echo "Pleasea confirm your infomation: 
password: $password
country: $country
state: $state
city: $city
organization: $organization
organizational_unit: $organizational_unit
email: $email
IP: $IP"
echo
read -p "Press any key to continue!"

# 以下是配置信息
# --[BEGIN]------------------------------

PASSWORD=$password
COUNTRY=$country
STATE=$state
CITY=$city
ORGANIZATION=$organization
ORGANIZATIONAL_UNIT=$organizational_unit
EMAIL=$email

# --[END]--

CODE="docker_api"

COMMON_NAME="$IP"

# Generate CA key
openssl genrsa -aes256 -passout "pass:$PASSWORD" -out "ca-key-$CODE.pem" 4096
# Generate CA
openssl req -new -x509 -days 365 -key "ca-key-$CODE.pem" -sha256 -out "ca-$CODE.pem" -passin "pass:$PASSWORD" -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"
# Generate Server key
openssl genrsa -out "server-key-$CODE.pem" 4096

# Generate Server Certs.
openssl req -subj "/CN=$COMMON_NAME" -sha256 -new -key "server-key-$CODE.pem" -out server.csr

echo "subjectAltName = IP:$IP,IP:127.0.0.1" >> extfile.cnf
echo "extendedKeyUsage = serverAuth" >> extfile.cnf

openssl x509 -req -days 365 -sha256 -in server.csr -passin "pass:$PASSWORD" -CA "ca-$CODE.pem" -CAkey "ca-key-$CODE.pem" -CAcreateserial -out "server-cert-$CODE.pem" -extfile extfile.cnf


# Generate Client Certs.
rm -f extfile.cnf

openssl genrsa -out "key-$CODE.pem" 4096
openssl req -subj '/CN=client' -new -key "key-$CODE.pem" -out client.csr
echo extendedKeyUsage = clientAuth >> extfile.cnf
openssl x509 -req -days 365 -sha256 -in client.csr -passin "pass:$PASSWORD" -CA "ca-$CODE.pem" -CAkey "ca-key-$CODE.pem" -CAcreateserial -out "cert-$CODE.pem" -extfile extfile.cnf

rm -vf client.csr server.csr

chmod -v 0400 "ca-key-$CODE.pem" "key-$CODE.pem" "server-key-$CODE.pem"
chmod -v 0444 "ca-$CODE.pem" "server-cert-$CODE.pem" "cert-$CODE.pem"

# 打包客户端证书
mkdir -p "tls-client-certs-$CODE"
cp -f "ca-$CODE.pem" "cert-$CODE.pem" "key-$CODE.pem" "tls-client-certs-$CODE/"
cd "tls-client-certs-$CODE"
tar zcf "tls-client-certs-$CODE.tar.gz" *
mv "tls-client-certs-$CODE.tar.gz" ../
cd ..
rm -rf "tls-client-certs-$CODE"

# 拷贝服务端证书
mkdir -p /srv/certs.d
cp "ca-$CODE.pem" "server-cert-$CODE.pem" "server-key-$CODE.pem" /srv/certs.d/