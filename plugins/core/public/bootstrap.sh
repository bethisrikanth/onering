#!/bin/sh
# onering boostrap.sh - "The worst way! (TM)"
#
which yum     > /dev/null 2>&1 && yum install -y --nogpgcheck ruby rubygems || \
which apt-get > /dev/null 2>&1 && apt-get install -y ruby rubygems

gem install facter json onering-client onering-report-plugins --no-ri --no-rdoc

rm -f /etc/cron.d/onering*
rm -f /etc/cron.d/obinventory*

cat <<EOF > /etc/cron.d/onering
PATH="/sbin:/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin"
*/5 * * * * root onering -q report --save > /dev/null 2>&1

EOF

onering report --save
