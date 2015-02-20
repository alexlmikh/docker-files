#!/bin/bash

set -e

NLP_TOOLSET_DIR=/NlpToolset
INIT_SCRIPT_PATH=$NLP_TOOLSET_DIR/init.sh

if [ -f $INIT_SCRIPT_PATH ];
then
	echo "Running custom init script: $INIT_SCRIPT_PATH"
	chmod +x $INIT_SCRIPT_PATH
	$INIT_SCRIPT_PATH
else
	echo "No init script found at $INIT_SCRIPT_PATH, you can see an example of the recommended script at https://github.com/Maluuba/NlpToolset/blob/master/init.sh"
fi

source /etc/profile.d/rvm.sh

cd $NLP_TOOLSET_DIR

rm -rf tmp/pids/server.pid

cp script/nlptoolset.conf /etc/init/nlptoolset.conf

rvm use jruby-1.7.10@nlp-toolset

bundle install

rake db:migrate

TOMCAT7_HOME=/usr/share/tomcat7

chown -R tomcat7:tomcat7 $TOMCAT7_HOME/nlptoolset/db

if [ "${RAILS_ENV}" == 'production' ]; then
	cp --recursive --force /tmp/ssh_mounted_keys/* $TOMCAT7_HOME/.ssh/
	chown tomcat7:tomcat7 $TOMCAT7_HOME/.ssh/id_rsa
	chmod 600 $TOMCAT7_HOME/.ssh/id_rsa
	chown tomcat7:tomcat7 $TOMCAT7_HOME/.ssh/known_hosts

	mvn package -Dnlp.toolset.rails.env=$RAILS_ENV
	service tomcat7 stop
	rm -rf /var/lib/tomcat7/webapps/ROOT*
	cp $NLP_TOOLSET_DIR/target/NlpToolset.war /var/lib/tomcat7/webapps/ROOT.war
	service tomcat7 restart

	start nlptoolset
else
	# Get default known_hosts.
	cp --recursive --force $TOMCAT7_HOME/.ssh/known_hosts /root/.ssh/known_hosts

	# In development mode, we run as root so we need the SSH keys in root's home.
	cp --recursive --force /tmp/ssh_mounted_keys/* /root/.ssh/
	chmod 600 /root/.ssh/id_rsa

	rails server --port=8080&
	sleep 20
	rake jobs:work&
fi

sleep 20
curl localhost:8080 || echo "Not up yet"

bash
