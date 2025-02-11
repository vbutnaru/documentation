#!/bin/sh

REPO_BRANCH=v3
BASE_DIR=${HOME}/Projects/eduVPN-${REPO_BRANCH}

mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}" || exit

# clone repositories (read-only)
git clone -b "${REPO_BRANCH}" https://git.sr.ht/~fkooman/vpn-user-portal
git clone -b "${REPO_BRANCH}" https://git.sr.ht/~fkooman/vpn-server-node
git clone -b v2 https://git.sr.ht/~fkooman/vpn-documentation
git clone https://git.sr.ht/~fkooman/vpn-portal-artwork-eduVPN
git clone https://git.sr.ht/~fkooman/vpn-portal-artwork-LC
git clone https://git.sr.ht/~fkooman/vpn-ca
git clone https://git.sr.ht/~fkooman/vpn-daemon
git clone https://git.sr.ht/~fkooman/wg-daemon
git clone https://git.sr.ht/~fkooman/vpn-maint-scripts
git clone https://git.sr.ht/~fkooman/builder.rpm
git clone https://git.sr.ht/~fkooman/builder.deb

# clone all repositories (read/write)
#git clone -b ${REPO_BRANCH} git@git.sr.ht:~fkooman/vpn-user-portal
#git clone -b ${REPO_BRANCH} git@git.sr.ht:~fkooman/vpn-server-node
#git clone -b v2 git@git.sr.ht:~fkooman/vpn-documentation
#git clone git@git.sr.ht:~fkooman/vpn-portal-artwork-eduVPN
#git clone git@git.sr.ht:~fkooman/vpn-portal-artwork-LC
#git clone git@git.sr.ht:~fkooman/vpn-ca
#git clone git@git.sr.ht:~fkooman/vpn-daemon
#git clone git@git.sr.ht:~fkooman/wg-daemon
#git clone git@git.sr.ht:~fkooman/vpn-maint-scripts
#git clone git@git.sr.ht:~fkooman/builder.rpm
#git clone git@git.sr.ht:~fkooman/builder.deb

# clone all RPM/DEB packages
mkdir -p rpm deb
for PACKAGE_NAME in vpn-daemon wg-daemon php-jwt php-oauth2-server vpn-ca vpn-portal-artwork-LC vpn-portal-artwork-eduVPN vpn-server-node vpn-user-portal vpn-maint-scripts; do
	git clone https://git.sr.ht/~fkooman/"${PACKAGE_NAME}".rpm rpm/"${PACKAGE_NAME}".rpm
#	git clone git@git.sr.ht:~fkooman/${PACKAGE_NAME}.rpm rpm/${PACKAGE_NAME}.rpm
##	git clone https://git.sr.ht/~fkooman/"${PACKAGE_NAME}".deb deb/"${PACKAGE_NAME}".deb
##	git clone git@git.sr.ht:~fkooman/${PACKAGE_NAME}.deb deb/${PACKAGE_NAME}.deb
done

######################################
# vpn-user-portal                    #
######################################
cd "${BASE_DIR}/vpn-user-portal" || exit
mkdir -p data
composer update

cat << EOF > config/config.php
<?php
\$baseConfig = include __DIR__.'/config.php.example';
\$localConfig = [
    //'styleName' => 'eduVPN',
    //'styleName' => 'LC',
    'secureCookie' => false,
    'vpnCaPath' => '${BASE_DIR}/vpn-ca/_bin/vpn-ca',
];
return array_merge(\$baseConfig, \$localConfig);
EOF

php libexec/init.php
php libexec/generate-secrets.php
php bin/add-user.php --user foo --pass bar

# symlink to the official templates we have so we can easily modify and test
# them
mkdir -p web/css web/img web/fonts
for TPL in eduVPN LC
do
    ln -s "${BASE_DIR}/vpn-portal-artwork-${TPL}/views"  "views/${TPL}"
    ln -s "${BASE_DIR}/vpn-portal-artwork-${TPL}/locale" "locale/${TPL}"
    ln -s "${BASE_DIR}/vpn-portal-artwork-${TPL}/css"    "web/css/${TPL}"
    ln -s "${BASE_DIR}/vpn-portal-artwork-${TPL}/img"    "web/img/${TPL}"
    ln -s "${BASE_DIR}/vpn-portal-artwork-${TPL}/fonts"  "web/fonts/${TPL}"
done

######################################
# vpn-ca                             #
######################################
cd "${BASE_DIR}/vpn-ca" || exit
go build -o _bin/vpn-ca vpn-ca/*.go

######################################
# vpn-daemon                         #
######################################
cd "${BASE_DIR}/vpn-daemon" || exit
go build -o _bin/vpn-daemon vpn-daemon/*.go

######################################
# wg-daemon                         #
######################################
#cd "${BASE_DIR}/vpn-daemon" || exit
#go build -o _bin/wg-daemon vpn-daemon/*.go

######################################
# vpn-server-node                    #
######################################
cd "${BASE_DIR}/vpn-server-node" || exit
mkdir -p data openvpn-config
composer update
cat << 'EOF' > config/config.php
<?php
$baseConfig = include __DIR__.'/config.php.example';
$localConfig = [
    'apiUrl' => 'http://localhost:8082/node-api.php',
];
return array_merge($baseConfig, $localConfig);
EOF

cp "${BASE_DIR}/vpn-user-portal/config/node.key" "${BASE_DIR}/vpn-server-node/config/node.key"

######################################
# launch script                      #
######################################
cat << 'EOF' | tee "${BASE_DIR}/launch.sh" > /dev/null
#!/bin/sh
cd vpn-user-portal || exit
php -S localhost:8082 -t web
EOF
chmod +x "${BASE_DIR}/launch.sh"
