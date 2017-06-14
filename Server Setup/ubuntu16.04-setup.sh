#!/bin/bash
#Steven Rollo
#
#Ubuntu Server 16.04 installer for PostgreSQL 9.6, Apache2 and pgAdmin 4 web
#
#Modified 2017 - 06 - 08

PREREQS="apache2 python-pip virtualenvwrapper libapache2-mod-wsgi build-essential"
PGURL="http://oscg-downloads.s3.amazonaws.com/packages/postgresql-9.6.3-1-x64-bigsql.deb"
PGDEB="postgresql-9.6.3-1-x64-bigsql.deb"
PGAWHEELURL="https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v1.5/pip/pgadmin4-1.5-py2.py3-none-any.whl"
PGAENVPATH="/opt/pgadmin4"
PGADATAPATH="/var/pgadmin4"

echo "Installing prerequisites..."
apt update
apt install -y $PREREQS
pip instal --upgrade pip
wget $PGURL
dpkg -i $PGDEB
apt install -f
rm $PGDEB
/opt/postgresql/pgc init pg96
systemctl start postgresql96

echo "Installation finished"
echo "Setting up pgAdmin4..."
mkdir $PGADATAPATH
virtualenv $PGAENVPATH
source $PGAENVPATH"/bin/activate"
pip install $PGAWHEELURL

cd $PGAENVPATH"/lib/python2.7/site-packages/pgadmin4"
cp config.py config_local.py

sed -i "s,DATA_DIR = os.path.realpath(os.path.expanduser(u'~/.pgadmin/')),DATA_DIR = '$PGADATAPATH',g" config_local.py
python setup.py

sed -i "/import sys/a execfile(activate_this, dict(__file__=activate_this))" pgAdmin4.wsgi
sed -i "/import sys/a activate_this = '$PGAENVPATH/bin/activate_this.py'" pgAdmin4.wsgi

chown -R www-data:www-data $PGAENVPATH
chown -R www-data:www-data $PGADATAPATH

echo "pgAdmin4 setup complete"
echo "Configuring Apache..."
ln -s $PGAENVPATH"/lib/python2.7/site-packages/pgadmin4" "/var/www/pgadmin4"

cat > /etc/apache2/sites-available/pgadmin4.conf <<- "EOF"
<VirtualHost *>
  ServerName pgadmin.local
  WSGIDaemonProcess pgadmin processes=1 threads=25
  WSGIScriptAlias / /var/www/pgadmin4/pgAdmin4.wsgi
  <Directory /var/www/pgadmin4>
    WSGIProcessGroup pgadmin
    WSGIApplicationGroup %{GLOBAL}
    Require all granted
  </Directory>
</VirtualHost>
EOF

a2dissite 000-default.conf
a2ensite pgadmin4.conf
systemctl restart apache2

echo "Setup complete!"

