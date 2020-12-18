#!/bin/bash

export CLIENT_CONF=/etc/openvpn/client-conf/client.ovpn

#config openvpn
if [ ! -f /etc/openvpn/server.conf ];then
    mkdir -p /etc/openvpn/auth 
    cp /install/server.conf /etc/openvpn/
    sed -i "s@proto tcp@proto $OVPN_PROTO@g" /etc/openvpn/server.conf
    sed -i "s@port 1194@port $OVPN_PORT@g" /etc/openvpn/server.conf

    cat > /etc/openvpn/auth/ldap.conf <<EOF
<LDAP>
	URL		$LDAP_URL
	BindDN		"$LDAP_BINDDN"
	Password	"$LDAP_BINDPW"
	Timeout		15
	TLSEnable	no
	FollowReferrals no
</LDAP>

<Authorization>
	BaseDN		"$LDAP_BASE"
	SearchFilter	"uid=%u"
	RequireGroup	false
</Authorization>
EOF
fi


init-pki(){
    cd $EASYRSA 
    source vars.example
    easyrsa clean-all
    easyrsa init-pki
    expect -c '
    	spawn easyrsa build-ca nopass
    	expect "*:"
    	send "\r"
	    expect eof
    '
    easyrsa gen-dh
    easyrsa build-server-full server nopass
    openvpn --genkey --secret $EASYRSA/pki/ta.key
    cp $EASYRSA/pki/{ca.crt,ta.key,issued/server.crt,private/server.key,dh.pem} "/etc/openvpn/"
}

#init-pki
if [ ! -f '/etc/openvpn/ca.crt' ];then
    init-pki
fi

#config ovpn-client
if [ $OVPN_PROTO = udp ];then
    sed -i "s@port 1194@port $OVPN_PORT@g" /etc/openvpn/server.conf
fi
if [ ! -d /etc/openvpn/client-conf ];then
    mkdir /etc/openvpn/client-conf -p
    cp /install/client.ovpn /etc/openvpn/client-conf/    
    sed -i "s/remote xxx\.xxx\.xxx\.xxx 443/remote $OVPN_ADDR $OVPN_PORT/" $CLIENT_CONF
    echo "<ca>" >> $CLIENT_CONF
    cat "/etc/openvpn/ca.crt" >> $CLIENT_CONF
    echo "</ca>" >> $CLIENT_CONF
    echo "<tls-auth>" >> $CLIENT_CONF
    cat "/etc/openvpn/ta.key" >> $CLIENT_CONF
    echo "</tls-auth>" >> $CLIENT_CONF

    if [ $OVPN_PROTO = udp ]; then
        sed -i "s/proto tcp-client/proto udp/g" $CLIENT_CONF
    fi
fi
#iptables init
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi
iptables -t nat -A POSTROUTING -s 10.254.254.0/24 -o eth0 -j MASQUERADE

/usr/sbin/openvpn --config /etc/openvpn/server.conf