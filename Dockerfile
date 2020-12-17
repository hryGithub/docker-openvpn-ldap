FROM alpine:3.12

RUN sed -i "s@dl-cdn.alpinelinux.org@mirrors.aliyun.com@g" /etc/apk/repositories && \
    apk add --no-cache expect openvpn iptables bash easy-rsa openvpn-auth-ldap && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin && mkdir -p /etc/openvpn/ccd 

ENV EASYRSA=/usr/share/easy-rsa

ADD ./install /install


#openvpn
ENV OVPN_ADDR=0.0.0.0 \ 
    OVPN_PORT=1194 \    
    OVPN_PROTO=udp

#ldap
ENV LDAP_URL='ldap://localhost:389' \
    LDAP_BASE='dc=example,dc=org' \
    LDAP_BINDDN='cn=admin,dc=example,dc=org' \
    LDAP_BINDPW='passwd' 


EXPOSE 1194/udp

ADD docker-entrypoint.sh /docker-entrypoint.sh 
ADD install /install


VOLUME ["/etc/openvpn/"]

ENTRYPOINT ["bash", "/docker-entrypoint.sh"]