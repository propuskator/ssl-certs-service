mkdir -p certs private
# DNS=localhost
if [[ -z "$DNS" ]] ; then
  echo "DNS env variable is required!"
  echo "EXIT!"
  exit 1
fi

# Create CA certificate
# private/ca-key.pem
if [ -e private/ca-key.pem ] && ! (openssl rsa -noout -text -in private/ca-key.pem -check >/dev/null) ; then
  echo "Wrong file format(private/ca-key.pem)"
  echo "Cleanup it"
  rm private/ca-key.pem
fi
if [ ! -e private/ca-key.pem ]; then
  echo "Creating file private/ca-key.pem"
  openssl genrsa -out private/ca-key.pem 2048
  echo 'Done!'
else
  echo "File private/ca-key.pem exists"
fi

# certs/ca.pem
if [ -e certs/ca.pem ] && ! (openssl x509 -noout -text -in certs/ca.pem | grep -q "RSA Public-Key") ;  then
  echo "Wrong file format(certs/ca.pem)"
  echo "Cleanup it"
  rm certs/ca.pem
fi
if [ -e certs/ca.pem ] ; then
  CERTMD5="$(openssl x509 -noout -modulus -in certs/ca.pem | openssl md5)"
  KEYMD5="$(openssl rsa -noout -modulus -in private/ca-key.pem | openssl md5)"
  if [ "$CERTMD5" != "$KEYMD5" ] ; then
    echo "File certs/ca.pem does not match private/ca-key.pem"
    echo "Cleanup it"
    rm certs/ca.pem
  else
    echo "File certs/ca.pem match to private/ca-key.pem"
  fi
  unset CERTMD5
  unset KEYMD5
fi

if [ ! -e certs/ca.pem ]; then
  echo "Creating file certs/ca.pem"
  openssl req -x509 -new -nodes -key private/ca-key.pem -sha256 -days 3650 -out certs/ca.pem -subj "/C=US/CN=rootca"
  echo 'Done!'
else
  echo "File certs/ca.pem exists"
fi

# Create server certificate, remove passphrase, and sign it
# server-cert.pem = public key, server-key.pem = private key
# private/server-key.pem
if [ -e private/server-key.pem ] && ! (openssl rsa -noout -text -in private/server-key.pem -check >/dev/null) ; then
  echo "Wrong file format(private/server-key.pem)"
  echo "Cleanup it"
  rm private/server-key.pem
fi
if [ ! -e private/server-key.pem ]; then
  echo "Creating file private/server-key.pem"
  openssl genrsa -out private/server-key.pem 2048
  echo 'Done!'
else
  echo "File private/server-key.pem exists"
fi

# certs/server-cert.pem
if [ -e certs/server-cert.pem ] && ( ! (openssl x509 -noout -text -in certs/server-cert.pem | grep -q "RSA Public-Key") || ! (openssl verify -CAfile certs/ca.pem certs/server-cert.pem  ) );  then
  echo "Wrong file format(certs/server-cert.pem)"
  echo "Cleanup it"
  rm certs/server-cert.pem
fi

if [ -e certs/server-cert.pem ] ; then
  CERTMD5="$(openssl x509 -noout -modulus -in certs/server-cert.pem | openssl md5)"
  KEYMD5="$(openssl rsa -noout -modulus -in private/server-key.pem | openssl md5)"
  if [ "$CERTMD5" != "$KEYMD5" ] ; then
    echo "File certs/server-cert.pem does not match private/server-key.pem"
    echo "Cleanup it"
    rm certs/server-cert.pem
  else
    echo "File certs/server-cert.pem match to private/server-key.pem"
  fi
  unset CERTMD5
  unset KEYMD5
fi

if [ -e certs/server-cert.pem ] ; then
  CERT_DNS=`openssl x509 -in certs/server-cert.pem -text -noout | grep -o "DNS:.*" | sed -e "s/DNS://"`
  if [ "$DNS" != "$CERT_DNS" ] ; then
    echo "File certs/server-cert.pem does not match provided dns"
    echo "Cleanup it"
    rm certs/server-cert.pem
  fi
  unset CERT_DNS
fi

if [ -e certs/server-cert.pem ] ; then
    ## 30 days before expiration in seconds
    EXPIRATION=$((30*24*60*60))

    ## Check expiration date
    if ! (openssl x509 -checkend $EXPIRATION -noout -in certs/server-cert.pem); then
        echo "Certificate has expired or will do so 30 days!"
        echo "Cleanup it"
        rm certs/server-cert.pem
    fi
fi
if [ ! -e certs/server-cert.pem ]; then
  echo "Creating file certs/server-cert.pem"

  rm -rf tmp
  mkdir -p reqs tmp
  touch tmp/conf.cnf

  eval "echo \"$(cat openssl_template.cnf)\"" > tmp/conf.cnf

  openssl req -config tmp/conf.cnf -new -sha256 -key private/server-key.pem -out reqs/server-req.pem -extensions x509_ext -extensions req_ext
  openssl x509 -req -in reqs/server-req.pem -CA certs/ca.pem -CAkey private/ca-key.pem -CAcreateserial -extensions x509_ext -extensions req_ext -extfile tmp/conf.cnf -out certs/server-cert.pem -days 825 -sha256

  cat certs/server-cert.pem certs/ca.pem > certs/fullchain.pem

  rm -rf tmp

  echo 'Done!'
else
  echo "File certs/server-cert.pem exists"
fi

echo 'Finish!'