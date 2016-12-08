#!/bin/bash

BPMS_USERNAME="bpmsAdmin"
BPMS_PASSWORD="password1!"

ROLE_TO_CHANGE="admin"
NEW_ROLE="admin"

JBOSS_HOME=./target/jboss-eap-7.0
SERVER_BIN=$JBOSS_HOME/bin
BRMS=jboss-brms-6.4.0.GA-deployable-eap7.x.zip
EAP=jboss-eap-7.0.0-installer.jar
EAP_PATCH=jboss-eap-7.0.3-patch.zip
LOGIN_MODULE=CustomLoginModule.jar
NEW_STANDALONE=standalone.xml
TRG_DIR=./target
SRC_DIR=./installs
SUPPORT_DIR=./configs
BUSINESS_CENTRAL=$JBOSS_HOME/standalone/deployments/business-central.war
BASEDIR=$(dirname "$0")

clear

echo "Install BRMS 6.4 and EAP 7.0"

# make some checks first before proceeding.
if [ -r $SRC_DIR/$EAP ] || [ -L $SRC_DIR/$EAP ]; then
	echo Product sources are present.
	echo
else
	echo Need to download $EAP package from the Customer Portal
	echo and place it in the $SRC_DIR directory to proceed.
	echo
	exit
fi

if [ -r $SRC_DIR/$EAP_PATCH ] || [ -L $SRC_DIR/$EAP_PATCH ]; then
	echo Product patches are present.
	echo
else
	echo Need to download $EAP_PATCH package from the Customer Portal
	echo and place it in the $SRC_DIR directory to proceed.
	echo
	exit
fi

if [ -r $SRC_DIR/$BRMS ] || [ -L $SRC_DIR/$BRMS ]; then
	echo JBoss product sources are present.
	echo
else
	echo Need to download $BRMS package from the Customer Portal
	echo and place it in the $SRC_DIR directory to proceed.
	exit
fi


# Remove the old JBoss instance, if it exists.
if [ -x $JBOSS_HOME ]; then
	echo "  - existing JBoss product install detected and removed."
	echo
	rm -rf ./target
fi


# Run installers.
echo "JBoss EAP installer running now."
echo
java -jar $SRC_DIR/$EAP $SUPPORT_DIR/eap-install.xml -variablefile $SUPPORT_DIR/eap-install.xml.variables

if [ $? -ne 0 ]; then
	echo
	echo Error occurred during JBoss EAP installation.
	exit
fi

rm -f $JBOSS_HOME/modules/system/layers/base/org/jboss/as/web/main/lib/linux-x86_64/libapr-1.so

echo
echo "Applying JBoss EAP 7.0.3 patch now..."
echo
$JBOSS_HOME/bin/jboss-cli.sh --command="patch apply $SRC_DIR/$EAP_PATCH --override-all"

if [ $? -ne 0 ]; then
	echo
	echo Error occurred during JBoss EAP patching.
fi

echo
echo "JBoss BRMS installer running now..."
echo
unzip -o $SRC_DIR/$BRMS -d $TRG_DIR
$SERVER_BIN/add-user.sh -a --user $BPMS_USERNAME --password $BPMS_PASSWORD --role kie-server,admin,rest-all,analyst

if [ $? -ne 0 ]; then
	echo
	echo Error occurred during JBoss BRMS installation.
	exit
fi

# Install additional custom login module from installs directory.
echo
echo "Installing custom login module for EAP..."
echo
cp -f $SRC_DIR/$LOGIN_MODULE $BUSINESS_CENTRAL/WEB-INF/lib
cp -f $SRC_DIR/$NEW_STANDALONE $JBOSS_HOME/standalone/configuration

if [ $? -ne 0 ]; then
	echo
	echo Error occurred during login module installation.
	exit
fi

# Change BRMS role names from ROLE_TO_CHANGE to NEW_ROLE.
echo
echo "Configuring BRMS roles..."
echo
sed -i -E "s/roles(.*)$ROLE_TO_CHANGE/\rroles\1$NEW_ROLE/" $BUSINESS_CENTRAL/WEB-INF/classes/workbench-policy.properties
sed -i -E "s/<role-name>$ROLE_TO_CHANGE/\<role-name>$NEW_ROLE/" $BUSINESS_CENTRAL/WEB-INF/web.xml

if [ $? -ne 0 ]; then
	echo
	echo Error occurred during role configuration.
	exit
fi


echo "==============================================="
echo
echo "BRMS 6.4 and EAP 7.0 are installed"
echo
echo "==============================================="
