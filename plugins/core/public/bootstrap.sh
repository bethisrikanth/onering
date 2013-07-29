#!/bin/bash
# onering boostrap.sh - "The worst way! (TM)"
#
quitcode(){
  echo -e "\033[31m[FATAL] $1\033[0m" 1>&2
  exit ${2:-1}
}


echo -e '\033[32mInstalling Ruby\033[0m'

which yum     > /dev/null 2>&1 && yum install -y --nogpgcheck ruby rubygems > /dev/null 2>&1 || \
which apt-get > /dev/null 2>&1 && apt-get install -y ruby rubygems > /dev/null 2>&1


which ruby > /dev/null 2>&1 || quitcode "Cannot find command: ruby"
which gem > /dev/null 2>&1 || quitcode "Cannot find command: gem"

echo -e '\033[32mInstalling Onering libraries\033[0m'
gem install facter json onering-client onering-report-plugins --no-ri --no-rdoc > /dev/null 2>&1

which onering > /dev/null 2>&1 || quitcode "Cannot find command: onering in $PATH"

ONERING_CLIENT_V=$(gem list onering-client | grep -Po -m1 '[0-9]+\.[0-9]+\.[0-9]+' | sort -nr | head -n1)
ONERING_PLUGIN_V=$(gem list onering-report-plugins | grep -Po -m1 '[0-9]+\.[0-9]+\.[0-9]+' | sort -nr | head -n1)

echo -e "\033[34mInstalled onering-client v${ONERING_CLIENT_V}, plugins v${ONERING_PLUGIN_V}\033[0m"

echo -e '\033[32mGenerating cron job\033[0m'

rm -f /etc/cron.d/onering* 2> /dev/null
rm -f /etc/cron.d/obinventory* 2> /dev/null

cat <<EOF > /etc/cron.d/onering
PATH="/sbin:/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin"
*/5 * * * * root onering -q report --save > /dev/null 2>&1

EOF

if [ ! -s /etc/hardware.id -o "$(cat /etc/hardware.id 2> /dev/null | grep hardwareid | wc -l)" -gt 0 ]; then
  onering fact hardwareid > /etc/hardware.id
  echo -e "\033[34mCreated hardware ID file: $(cat /etc/hardware.id)\033[0m"
fi

echo -e '\033[32mRetrieving validation certificate\033[0m'
mkdir -p /etc/onering
curl -s -f 'http://onering.outbrain.com/validation.pem' > /etc/onering/validation.pem

echo -e '\033[32mPerforming inventory\033[0m'

for i in 1 2; do
  onering -q report --save 2> /dev/null
done

echo -e "\033[32mDONE!\033[0m"
echo "View this machine at https://onering.outbrain.com/#/node/$(onering fact hardwareid)"

exit 0
