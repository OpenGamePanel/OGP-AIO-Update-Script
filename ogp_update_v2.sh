#!/bin/bash
# Author:  own3mall (own3mall@gmail.com)
# About:  Installs the latest OGP Agent and Web Panel Update Version
# First make database backup through PHPMyAdmin
# ---------------- START SCRIPT ----------------- #

##---------------------------------------------##
## FUNCTIONS                                   ##
##---------------------------------------------##

function importOGPDB(){
	
	cd "$bkdirDB"
	if [ -e "ogp.sql" ]; then
		if mysql -h "$MYSQLSERVER" -u "$DBUSER" -p"$DBPASS" "$DBNAME" -f < ogp.sql; then
			echo -e "\nSuccessfully imported OGP MySQL data and settings from the old installation."
			rm -R "ogp.sql"
		else
			echo -e "\nFailed to import the database! Serious error!"
			exit
		fi
		
	else
	   echo -e "\nNo OGP MySQL backup exists. Nothing to import."
	fi
}

function getOGPDatabase(){
	cd "$OGP_WEB_PATH/includes"
	if [ -e "config.inc.php" ]; then
		DBNAME=$(cat config.inc.php | grep -o "\$db_name.*" | grep -o "=.*" | grep -o "[^=\"].*" | grep -o "[^\";]*")
		DBUSER=$(cat config.inc.php | grep -o "\$db_user.*" | grep -o "=.*" | grep -o "[^=\"].*" | grep -o "[^\";]*")
		DBPASS=$(cat config.inc.php | grep -o "\$db_pass.*" | grep -o "=.*" | grep -o "[^=\"].*" | grep -o "[^\";]*")
		MYSQLSERVER=$(cat config.inc.php | grep -o "\$db_host.*" | grep -o "=.*" | grep -o "[^=\"].*" | grep -o "[^\";]*")
	fi
	
	cd "$OGP_AGENT_PATH/Cfg"
	if [ -e "Config.pm" ]; then
		ENCRYPTION_KEY=$(cat Config.pm | grep -o "key => '.*" | grep -o "'.*" | grep -o "[^'].*" | grep -o "[^',]*")
		OGPUSERSUDOPASS=$(cat Config.pm | grep -o "sudo_password => '.*" | grep -o "'.*" | grep -o "[^'].*" | grep -o "[^',]*")
	fi
}

function promptDirs(){
	
  # Retrieve saved values if they exist from earlier use
  OGPSAVEDSET="$ORIGDIR/ogpupdate_paths.cfg"
  if [ -e "$OGPSAVEDSET" ]; then
		CONTENT=$(cat "$OGPSAVEDSET")
		if [ ! -z "$CONTENT" ]; then 
			source "$OGPSAVEDSET"
		fi
  else
		touch "$OGPSAVEDSET"
  fi
  
  if [ -z "$OGP_AGENT_PATH" ] || [ -z "$OGP_WEB_PATH" ]; then
	
	  echo -e "Where are the OGP agent files isntalled on this server [for example: /games/OGP]?"
	  echo -n "Please enter the path now: "
	  read OGP_AGENT_PATH
	  echo "OGP_AGENT_PATH=$OGP_AGENT_PATH" >> "$OGPSAVEDSET"
	  echo -e "\nWhere are the OGP web panel files installed on this server [for example: /var/www/opengamepanel]?"
	  echo -n "Please enter the path now: "
	  read OGP_WEB_PATH
	  echo "OGP_WEB_PATH=$OGP_WEB_PATH" >> "$OGPSAVEDSET" 
	  
  fi
  
  echo -e "\nOGP Agent path is currently set to \"$OGP_AGENT_PATH\""
  echo -e "OGP Web path is currently set to \"$OGP_WEB_PATH\"\n"
  
  echo -n "Are these values correct [y/n]: "
  read correctDB
  correctDB=$(echo "$correctDB" | awk '{print tolower($0)}')

  if [ -z "$correctDB" ] || [ "$correctDB" == "n" ]; then
	 OGP_WEB_PATH=""
	 if [ -e "$OGPSAVEDSET" ]; then
		rm "$OGPSAVEDSET"
	 fi
     promptDirs
     
  else
  
	  # Error counter variable
	  Errcount=0
	  ErrMess="Encounterd the following errors:"
	  
	  if [ ! -e "$OGP_AGENT_PATH" ] || [ ! -e "$OGP_AGENT_PATH/ogp_agent.pl" ] ; then
		Errcount=$((Errcount + 1))
		ErrMess="$ErrMess\n$OGP_AGENT_PATH does not exist or is not your OGP Agent directory!"
	  fi
	  
	  if [ ! -e "$OGP_WEB_PATH" ] || [ ! -e "$OGP_WEB_PATH/includes" ]; then
		Errcount=$((Errcount + 1))
		ErrMess="$ErrMess\n$OGP_WEB_PATH does not exist or is not your OGP Web Panel directory!"
	  fi
	  
	  if [ $Errcount -gt "0" ]; then
		echo -e "\n$ErrMess\n"
		promptDirs
	  fi
  
  fi
  
  
}

function determineApacheUser(){
  apacheUser=$(ps aux | grep apache | awk '{ print $1}' | awk 'NR==2')
  
  if [ -z "$apacheUser" ]; then
     apacheUser=$(ps aux | grep apache | awk '{ print $1}' | awk 'NR==1')
     if [ -z "$apacheUser" ]; then
        apacheUser="root"
     fi
  fi
}

function createNeededDirs(){

  bkdir="/root/Backups"
  bkdirOGP="/root/Backups/OGP"
  bkdirAgent="/root/Backups/OGP/Agent"
  bkdirWeb="/root/Backups/OGP/Web"
  bkdirDB="/root/Backups/OGP/Database"
  dldir="/root/Downloads"
  ogpdldir="/root/Downloads/OGP_Latest"
  
  # User prompted directories
  
  dirsNeeded=()
  dirsNeeded+=("$bkdir")
  dirsNeeded+=("$bkdirOGP")
  dirsNeeded+=("$bkdirAgent")
  dirsNeeded+=("$bkdirAgent/tmp")
  dirsNeeded+=("$bkdirWeb")
  dirsNeeded+=("$bkdirWeb/tmp")
  dirsNeeded+=("$bkdirDB")
  dirsNeeded+=("$dldir")
  dirsNeeded+=("$ogpdldir")

  for i in ${dirsNeeded[@]}; do
    if [ ! -e "$i" ]; then
      mkdir "$i"; 
    fi
  done
}

function checkForSVN(){
	which svn > /dev/null
	if [ $? -eq 1 ]; then
		echo -e "\nUpdate script unable to automatically install SVN on your system.\nPlease install the subversion (SVN) package and run this upgrade script again!"
		exit 1
	fi
}

function aptgetInstall(){

	# Do not prompt, just install
	cmd="apt-get -y --no-remove --allow-unauthenticated install $1"
	$cmd
	
	if [ $? -ne 0 ]; then
		cmd="apt-get --allow-unauthenticated install $1"
		$cmd	
	fi

}

function notOGPDB(){
  echo -e "\n$DBNAME is not your OGP MySQL database! Please try again!"
  if [ -e "$OGPSAVEDSET" ]; then
	rm "$OGPSAVEDSET"
  fi
  mysqldumpFile
}

function dateStamp(){
  DATENOW=$(date +"%m_%d_%Y_%H%M%S")
}

function mysqldumpFile(){
	
  if [ -z "$SKIPDBCHECK" ]; then 
	# See if we can pull the mysql database in use by OGP
	getOGPDatabase
  fi
  
  # Retrieve saved values if they exist from earlier use
  OGPSAVEDSET="$ORIGDIR/ogpupdate_sql.cfg"
  if [ -e "$OGPSAVEDSET" ]; then
		CONTENT=$(cat "$OGPSAVEDSET")
		if [ ! -z "$CONTENT" ]; then 
			source "$OGPSAVEDSET"
		fi
  else
		touch "$OGPSAVEDSET"
  fi

  if [ -z "$DBNAME" ] || [ -z "$DBUSER" ] || [ -z "$DBPASS" ] || [ -z "$MYSQLSERVER" ]; then
	
	echo -e "\n"
	echo -n "Please enter the database name for the OGP web panel: "
	read DBNAME
	echo "DBNAME=$DBNAME" >> "$OGPSAVEDSET"
	
	echo -n "Please enter the database username for the OGP web panel: "
	read DBUSER
	echo "DBUSER=$DBUSER" >> "$OGPSAVEDSET"
	
	echo -n "Please enter the database password for $DBUSER: "
	read DBPASS
	echo "DBPASS=$DBPASS" >> "$OGPSAVEDSET"
	
	echo -n "Please enter the database host (usually localhost): "
	read MYSQLSERVER
	echo "MYSQLSERVER=$MYSQLSERVER" >> "$OGPSAVEDSET"	
	echo -e "\n"
	
  fi
  
  echo -e "OGP database name is currently set to \"$DBNAME\"."
  echo -e "OGP database username is currently set to \"$DBUSER\"."
  echo -e "OGP database password is currently set to \"$DBPASS\"."
  echo -e "The database host is currently set to \"$MYSQLSERVER\".\n"

  echo -n "Are these values correct [y/n]: "
	
  read correctDB
  correctDB=$(echo "$correctDB" | awk '{print tolower($0)}')

  if [ -z "$correctDB" ] || [ "$correctDB" == "n" ]; then
  	if [ -e "$OGPSAVEDSET" ]; then
		rm "$OGPSAVEDSET"
	fi
	DBNAME=""
	SKIPDBCHECK="1"
	mysqldumpFile
  fi
  
  if ! mysql -h "$MYSQLSERVER" -u "$DBUSER" -p"$DBPASS" "$DBNAME" -e ";" ; then
	 echo -e "\nUnable to establish a connection to the MySQL database using the supplied DB information.\nTry again!\n"
	 notOGPDB
  fi
  
}

function backupDB(){
  if [ -e /etc/init.d/mysql ]; then
	if [ ! -z "$DBNAME" ]; then
      if mysql -e "use $DBNAME" -u "$DBUSER" -p"$DBPASS" ; then
        
        # Get OGP prefix
        echo -e "\nGetting a list of tables from the database!"
        dbquery=$(mysql -e "SHOW TABLES IN $DBNAME" -u "$DBUSER" -p"$DBPASS")
        array=( $( for i in $dbquery ; do echo $i ; done ) )

        firstTable=${array[1]};
        
        if [ ! -z "$firstTable" ]; then
		  echo -e "\nDetecting OGP database prefix!"
          OGP_PREFIX=$(echo "$firstTable" | grep -o ".*_")
          if [ -z "$OGP_PREFIX" ]; then
			  echo -e "\nNo OGP database prefix detected... you must not be using a prefix, which is fine."
			  NO_OGPPREFIX="1"
		  else
			  echo -e "\nOGP database prefix detected as \"$OGP_PREFIX\"";
		  fi
		  
		  sleep 3
          
          # This is for sure the OGP database, so dump current settings
          echo -e "\nDumping database backup!"
          
          DBBackupFile="$bkdirDB/ogp.sql"
          DBBackupFile2="$bkdirDB/ogp2.sql"
          
          if [ -e "$DBBackupFile" ]; then
			 rm "$DBBackupFile"
          fi
          
          touch $DBBackupFile
          
          if [ ! -z "$1" ] && [ "$1" == "installCleanThenUpdate" ]; then
			SQLChangesExist=$(wget -O /dev/null -q "http://dinofly.com/files/ogp/ogp_insupdate.sql" && echo exists || echo not exist)
			if [ "$SQLChangesExist" == "exists" ]; then
				wget -N -O "ogpsql" "http://dinofly.com/files/ogp/ogp_insupdate.sql"
				
				# Replace OGP Prefix with actual prefix
				if [ -e "ogpsql" ]; then
					sed -i "s/{OGP_DB_PREFIX}/$OGP_PREFIX/g" "ogpsql"
				fi
				
				if mysql -f -h "$MYSQLSERVER" -u "$DBUSER" -p"$DBPASS" "$DBNAME" < "ogpsql"; then
					echo -e "\nOGP structural database changes were applied in accordance to new changes to OGP so that your existing dataset will work in the freshly upgraded new version!"
				else
					echo -e "\nSQL structural database changes need to be made to the database structure before proceeding, but the changes failed!\nSkipping backup step!";
					exit
				fi
			fi
		  fi

		  if mysqldump -h "$MYSQLSERVER" -u "$DBUSER" -p"$DBPASS" --skip-triggers --compact --complete-insert --insert-ignore "$DBNAME" > "$DBBackupFile"; then
			 sed -i 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' "$DBBackupFile"
			 mv "$DBBackupFile" "$DBBackupFile2"
			 echo -e "DELETE FROM ${OGP_PREFIX}widgets_users;\n" > "$DBBackupFile"
			 cat "$DBBackupFile2" >> "$DBBackupFile"
			 rm "$DBBackupFile2"
			 echo -e "\nDatabase backup saved to $DBBackupFile"		  
		  else
			 echo -e "\nFailed to backup database";
			 exit
		  fi        
          
      
        else
          notOGPDB  
        fi
      else
        notOGPDB
      fi
    else
		mysqldumpFile
    fi
  fi
}

function installAgent(){
  
	sleep 2
	# Run install and send the user already 
	bash ./install.sh "update" "$AGENTOWNER" "$OGPUSERSUDOPASS" "$OGP_AGENT_PATH"
	wait
	  
}

function getAdminLoginDetails(){
	# Do the next step.  We need the admin_username, password, email_address
	# May try to detect these automatically later
	
	OGPSAVEDSET="$ORIGDIR/ogpupdate_webconf.cfg"
	if [ -e "$OGPSAVEDSET" ]; then
		CONTENT=$(cat "$OGPSAVEDSET")
		if [ ! -z "$CONTENT" ]; then 
			source "$OGPSAVEDSET"
		fi
	else
		touch "$OGPSAVEDSET"
	fi

	if [ -z "$WEBADMINLOGIN" ] || [ -z "$WEBADMINPASS" ] || [ -z "$WEBADMINEMAIL" ]; then
		
		echo -e "\n"
		echo -n "Please enter the current admin login for the panel: "
		read WEBADMINLOGIN
		echo "WEBADMINLOGIN=$WEBADMINLOGIN" >> "$OGPSAVEDSET"	
		
		echo -n "Please enter the current admin passwod for the panel: "
		read WEBADMINPASS
		
		echo "WEBADMINPASS=$WEBADMINPASS" >> "$OGPSAVEDSET"	
		
		echo -n "Please enter the current email address for the panel: "
		read WEBADMINEMAIL
		echo "WEBADMINEMAIL=$WEBADMINEMAIL" >> "$OGPSAVEDSET"	
	
	fi
	
	if [ "${#WEBADMINPASS}" -lt "6" ]; then
		echo -e "\nPassword must be at least 6 characters.  Please try again!"
		restartWebInsPart2
	fi
	
	echo -e "\nAdmin login for the OGP web panel is set to \"$WEBADMINLOGIN\"."
	echo -e "Admin password for the OGP web panel is set to \"$WEBADMINPASS\"."
	echo -e "Admin email address for the OGP web panel is set to \"$WEBADMINEMAIL\".\n"

	echo -n "Are these values correct [y/n]: "
	
	read correctDB
	correctDB=$(echo "$correctDB" | awk '{print tolower($0)}')

	if [ -z "$correctDB" ] || [ "$correctDB" == "n" ]; then
		restartWebInsPart2
	fi
}

function installWebPart2(){
		
	getAdminLoginDetails
	if [ ! -z "$WEBADMINLOGIN" ]; then
		/usr/bin/php "$ORIGDIR/ogp_web_install_db.php" "$OGPLOCALURL/install.php" "step=3" "username=$WEBADMINLOGIN" "password1=$WEBADMINPASS" "password2=$WEBADMINPASS" "email=$WEBADMINEMAIL"
		wait	
	fi
}

function restartWebInsPart2(){
	if [ -z "$1" ]; then
		if [ -e "$OGPSAVEDSET" ]; then
			rm "$OGPSAVEDSET"
		fi
	fi
	WEBADMINLOGIN=""
	getAdminLoginDetails
}

function restartWebInsPart1(){
	if [ -e "$OGPSAVEDSET" ]; then
			rm "$OGPSAVEDSET"
	fi
	OGPLOCALURL=""
	installWeb
}

function installWeb(){
	
	# Removed the following because it still doesn't work...
	#echo -e "\nChecking to make sure tmp dir perms are correct!"
	#tmpDirPermsCheck
	#sleep 5
	
	INSTALLMETH="$ORIGDIR/ogpupdate_method.cfg"
	if [ -e "$INSTALLMETH" ]; then
		CONTENT=$(cat "$INSTALLMETH")
		if [ ! -z "$INSTALLMETH" ]; then 
			source "$INSTALLMETH"
		fi
	else
		touch "$INSTALLMETH"
	fi
	
	if [ -z "$updateMethodOGP" ]; then
		echo -e "\n"
		echo -e "This script can update OGP using two different methods.\n"
		echo -e "It is recommended to use the update module method (known as the \"panel\" method).\n"
		echo -e "If your version of OGP is release version 2644 or older than April 2013, enter \"n\" when prompted to use the update module method (known as the \"installCleanThenUpdate\" method).\nThis method will install a new fresh copy and then reimport the old data that still applies to the new structure.\n"
		echo -n "Use OGP's update module to update the panel? [y/n]: "
		read OGPUPMETH
		
		OGPUPMETH=$(echo "$OGPUPMETH" | awk '{print tolower($0)}')

		if [ -z "$OGPUPMETH" ] || [ "$OGPUPMETH" == "y" ]; then
			updateMethodOGP="panel"
		else
			updateMethodOGP="installCleanThenUpdate"
		fi
		
		echo "updateMethodOGP=$updateMethodOGP" > "$INSTALLMETH"
		
	fi
	
	echo -e "\n\nOGP upgrade method is set to \"$updateMethodOGP\".\n"

	echo -n "Is this the upgrade method you'd like to use? [y/n]: "
		
	read correctDB
	correctDB=$(echo "$correctDB" | awk '{print tolower($0)}')

	if [ -z "$correctDB" ] || [ "$correctDB" == "n" ]; then
		if [ -e "$INSTALLMETH" ]; then
			rm "$INSTALLMETH"
		fi
		unset updateMethodOGP
		installWeb
	else
	
		OGPSAVEDSET="$ORIGDIR/ogpupdate_urltopanel.cfg"
		if [ -e "$OGPSAVEDSET" ]; then
			CONTENT=$(cat "$OGPSAVEDSET")
			if [ ! -z "$CONTENT" ]; then 
				source "$OGPSAVEDSET"
			fi
		else
			touch "$OGPSAVEDSET"
		fi
		
		if [ -z "$OGPLOCALURL" ] ; then
			
			echo -e "\n"
			echo -n "Please enter your panel's URL reachable from the server (for example: http://localhost/opengamepanel): "
			read OGPLOCALURL
			echo "OGPLOCALURL=$OGPLOCALURL" >> "$OGPSAVEDSET"
			
			# Error counter variable
			Errcount=0
			ErrMess="Encounterd the following errors:"
			
			# do some syntax checking
			# Has http:// in url
			hasHTTP=$(echo "$OGPLOCALURL" | grep "http://")
			if [ -z "$hasHTTP" ]; then			
				Errcount=$((Errcount + 1))
				ErrMess="$ErrMess\nYou must include http:// in the URL! Please try again!"
			fi	
			
			hasWWW=$(echo "$OGPLOCALURL" | grep "www.")
			if [ ! -z "$hasWWW" ]; then
				Errcount=$((Errcount + 1))
				ErrMess="$ErrMess\nDo not put \"www.\" into the URL! Please try again!"
			fi	
			
			#Check last char isn't /
			LASTCHAR=$(echo "${OGPLOCALURL: -1}")
			if [ "$LASTCHAR" == "/" ]; then
				Errcount=$((Errcount + 1))
				ErrMess="$ErrMess\nDo not put a foward slash \"/\" at the end of the URL!"
			fi

			# Check that it is reacheable
			wget --spider "$OGPLOCALURL"
			URLREACH=$(echo "$?")
			if [ "$URLREACH" != "0" ]; then
				Errcount=$((Errcount + 1))
				ErrMess="$ErrMess\nServer cannot reach the URL! Please try again!"
			fi
			
		fi
		
		if [ $Errcount -gt "0" ]; then
				echo -e "\n$ErrMess\n"
				restartWebInsPart1
		else
		
			echo -e "\n\nOGP web panel URL is set to \"$OGPLOCALURL\".\n"

			echo -n "Is this value correct [y/n]: "
			
			read correctDB
			correctDB=$(echo "$correctDB" | awk '{print tolower($0)}')

			if [ -z "$correctDB" ] || [ "$correctDB" == "n" ]; then
				restartWebInsPart1
			else
				cd "$ORIGDIR"
				echo -e "\nAttempting to automatically install the web panel using selected method of $updateMethodOGP \n"
				if [ "$updateMethodOGP" != "panel" ]; then
					useCleanInstallUpdate
				else
					# We are using the panel's update functionality
					
					# Copy new upload files into the directory and then run OGP's version
					cd "$ogpdldir"
					cd "trunk"
					cd "upload"
					
					cp -Rf ./* "$OGP_WEB_PATH"
					cd "$OGP_WEB_PATH"
					
					if [ -e "install.php" ]; then
						rm -f install.php
					fi
					
					# Fix permissions
					fixPerms
					
					# Go back to original directory
					cd "$ORIGDIR"
					
					#backupDB
					runDBBackup
					
					#Get admin credentials
					getAdminLoginDetails
					
					# Use panel update utility
					useOGPUpdate
				fi
			fi
		fi
	fi
}

function useCleanInstallUpdate(){
	
	# Make sure we use the installCleanThenUpdate Method Since Finishing Code relies on this to be set properly if using this method
	# It needs to be reset here because the user may choose to use this update method if the panel update fails, so we must reset it.
	updateMethodOGP="installCleanThenUpdate"
	
	# Clear any existing files in the OGP Web Path
	rm -R "$OGP_WEB_PATH"
					
	# Install latest web panel version
	cd "$ogpdldir"
	cd "trunk"
					 
	if [ ! -e "$OGP_WEB_PATH" ]; then
		mkdir -p "$OGP_WEB_PATH"
	fi
					  
	# Copy latest files to OGP Web Path
	cp -Rf upload/* "$OGP_WEB_PATH"
	cd "$OGP_WEB_PATH"
	cd includes
	touch config.inc.php
	chmod 777 config.inc.php
	cd "$OGP_WEB_PATH/modules/TS3Admin"
	if [ ! -e templates_c ]
	then
		mkdir templates_c
	fi 
	chmod -R 777 templates_c
					
	# Fix permissions
	fixPerms
					
	# Go back to original directory
	cd "$ORIGDIR"
					
	# backupDB
	runDBBackup
					
	# Use fresh install then reimport database...
	/usr/bin/php "$ORIGDIR/ogp_web_install_db.php" "$OGPLOCALURL/install.php" "step=2" "db_host=$MYSQLSERVER" "db_user=$DBUSER" "db_pass=$DBPASS" "db_name=$DBNAME" "table_prefix=$OGP_PREFIX"
	wait
	installWebPart2
}

function useOGPUpdate(){
	# Fix the panel update URLs so that the panel's update method works again due to SourceForge.net HTTPS changes
	applySourceForgeURLFixesToDoLatestUpdate
	
	# Run a couple of checks to make sure we don't get any output with the class of failure indicating that this should have updated successfully:
	removePossErrors
	
	curl --data "ulogin=$WEBADMINLOGIN&upassword=$WEBADMINPASS&login=login" --cookie lejgjt4vdp62hchx --cookie-jar lejgjt4vdp62hchx "$OGPLOCALURL/index.php" > output
	curl --cookie lejgjt4vdp62hchx --cookie-jar lejgjt4vdp62hchx "$OGPLOCALURL/home.php?m=update&p=updating&version=$REVISION" >> output
	ogpupdatemodulesucceeded=$(cat output | grep "success")
	ogpupdatemodulefailed=$(cat output | grep "failure")

	if [ ! -z "$ogpupdatemodulefailed" ] && [ -z "$ogpupdatemodulesucceeded" ]; then
		echo -e "\n\nUpdating OGP using the update module failed most likely due to invalid credentials!\n\n"
		echo -e "\nHere is the reason why it failed:\n"
		echo $(cat output | grep "failure")
		
		echo -e "\n"
		echo -n "Would you like to try this update method again? (y/n) (if \"n\", we will try using a clean install update): "
		read tryUpdateOGPPanelAgain
		
		tryUpdateOGPPanelAgain=$(echo "$tryUpdateOGPPanelAgain" | awk '{print tolower($0)}')

		if [ -z "$tryUpdateOGPPanelAgain" ] || [ "$tryUpdateOGPPanelAgain" == "n" ]; then
			removeCookieStuff			
			useCleanInstallUpdate
		else
			# Reprompt for admin credentials
			restartWebInsPart2 "noRemove"
			
			# Try this method again
			useOGPUpdate
		fi
	else
		echo -e "\n\nSuccessfully updated OGP using the update module\n\n"
		removeCookieStuff
	fi
	
}

function removeCookieStuff(){
	if [ -e "lejgjt4vdp62hchx" ]; then
		rm -f lejgjt4vdp62hchx
	fi
	
	if [ -e "output" ]; then
		rm -f output
	fi
}

function removePossErrors(){
	oDir=$(pwd)
	
	# Delete install.php if it exists
	cd "$OGP_WEB_PATH"
	if [ -e "install.php" ]; then
		echo -e "\nRemoving install.php"
		rm -f install.php
	fi
	if [ -e "includes" ]; then
		cd includes
		if [ -e "config.inc.php" ]; then
			chmod 644 "config.inc.php"
		fi
	fi
	cd "$oDir"
	
}

function fixPerms(){
	echo -e "\nApplying original ownership permissions on files."
	# Restore original owner 
	if [ ! -z "$WEBOWNER" ]; then
		echo -e "\nOwner of files is $WEBOWNER."
		chown -R "$WEBOWNER" "$OGP_WEB_PATH"
	fi	
}

function runDBBackup(){
  inDir=$(pwd)
  cd "$bkdirDB"
  
  if [ -z "$updateMethodOGP" ]; then
	backupDB
  else
	if [ "$updateMethodOGP" == "panel" ]; then
		backupDB
	else
		backupDB "$updateMethodOGP"
	fi
  fi
  
  if [ -e "ogp.sql" ]; then
    tar -cvzf $(date +"%m_%d_%Y_%H%M%S")_ogpsql.tar.gz "ogp.sql"
  fi
  echo -e "\n\nMySQL database backup completed and archived in $bkdirDB!"
  
  # Go back to original dir
  cd "$inDir"
}

function finishInstall(){
	
	# Install web 
	installWeb
	
	webInstalled=$(cat "$OGP_WEB_PATH/includes/config.inc.php")
		
	if [ -z "$webInstalled" ]; then
	
		echo -e "\n\nPlease install the web portion using your browser (http://localhost/urpath/install.php)."
		echo -e "\nUse the below information for the web panel installation:"
		echo -e "Your OGP database name as \"$DBNAME\"."
		echo -e "Your OGP database username as \"$DBUSER\"."
		echo -e "Your OGP database password as \"$DBPASS\".\n"
		echo -e "\nReturn to this script immediately after the admin account has been successfully created and you've been notified that installation is complete."
		echo -e "The install will want you to chmod config.inc.php to 644, but our script will do that for you, so switch back to the script when you see this screen!\n" 
		echo -n "When finished installing the OGP web portion, please type go: "
		read CONT
		
		CONT=$(echo "$CONT" | awk '{print tolower($0)}')

		if [ "$CONT" == "go" ]; then
		
			# Check to make sure the panel has been installed by verifying the config.inc.php file contains data
			webInstalled=$(cat "$OGP_WEB_PATH/includes/config.inc.php")
			
			if [ -z "$webInstalled" ]; then
				echo -e "\nYou did NOT run the OGP web panel installation script! The update script will not finish until OGP has been installed via the OGP install script (install.php)."
				finishInstall				
			fi
		else
			echo -e "\nYOU MUST TYPE \"go\" without the quotes (\"\") TO IMPORT YOUR OLD SETTINGS AND PROPERLY UPGRADE YOUR PANEL!\nTry again!"
			finishInstall
		fi
	
	else
	
		# Copy old game files but don't overwrite back to OGP web directory
		echo -e "\nCopying any non-indexed game server / module / theme configurations back into the web panel directory!"
		cd "$bkdirWeb"
		cd "tmp"
		if [ -e "install.php" ]; then
			rm "install.php"
		fi
		cp -R -n ./* "$OGP_WEB_PATH"
		cd ..
		rm -R "tmp"
				  
		if [ "$updateMethodOGP" != "panel" ]; then
				  
			# OK the panel should be installed now by the user... lets secure OGP
			echo -e "\nDeleting the installation files and chmoding protected files in $OGP_WEB_PATH!"
			rm "$OGP_WEB_PATH/install.php"
			cd "$OGP_WEB_PATH/includes" 
			chmod 644 config.inc.php
				  
			echo -e "\nImporting the database backup containing OGP settings and data."
			# Time to reimport the database, just the insert commands since database structure may have changed (create statements should be ignored since the tables already theoretically exist...
			importOGPDB
			
		fi
				
		# Fix permissions
		fixPerms
		
	fi
}

function performSVNCheckout(){
	if [ ! -e "trunk" ]; then
		REVISION=$(svn checkout "$SVN_URL" trunk | grep -Po '(?<=Checked out revision )[0-9]+')
		sleep 2
		if [ ! -e "trunk" ]; then
			performSVNCheckout
		fi
	fi
}

function tmpDirPermsCheck(){
	OGPWUTMPATH="/tmp/OGP_update/"
	if [ ! -e "$OGPWUTMPATH" ]; then
		mkdir -p "$OGPWUTMPATH"
	fi
	if [ -z "$WEBOWNER" ]; then
		determineApacheUser
		WEBOWNER="$apacheUser"
	fi
	chown -R "$WEBOWNER" "$OGPWUTMPATH"
	chmod 1777 -R "$OGPWUTMPATH"
}

function applySourceForgeURLFixesToDoLatestUpdate(){
	# Get current directory that we're in
	inDir=$(pwd)
	
	# Make SourceForge URL Changes in Agent Files
	cd "$OGP_AGENT_PATH"
	if [ -e "$OGP_AGENT_PATH/ogp_agent_run" ]; then
		sed -i 's#http://\${MIRROR}.dl.sourceforge.net/project/ogpextras/Alternative-Snapshot/linux-agent-\${REVISION}.zip#https://\${MIRROR}.dl.sourceforge.net/project/ogpextras/Alternative-Snapshot/linux-agent-\${REVISION}.zip#g' "$OGP_AGENT_PATH/ogp_agent_run"
		sed -i 's#\$(curl -b "FreedomCookie=true;path=/;expires=\$expires" -Os --head -w "%{http_code}" "\$URL")#\$(curl -L --insecure -b "FreedomCookie=true;path=/;expires=\$expires" -Os --head -w "%{http_code}" "\$URL")#g' "$OGP_AGENT_PATH/ogp_agent_run"
		sed -i 's#curl -b "FreedomCookie=true;path=/;expires=\$expires" -Os \$URL#curl -L --insecure -b "FreedomCookie=true;path=/;expires=\$expires" -Os \$URL#g' "$OGP_AGENT_PATH/ogp_agent_run"
	fi
	
	# Make SourceForge URL Changes in Web Files
	cd "$OGP_WEB_PATH"
	if [ -e "$OGP_WEB_PATH/modules/update/update.php" ]; then
		sed -i 's#http://sourceforge.net/projects/ogpextras/rss?path=/Alternative-Snapshot\&limit=3#https://sourceforge.net/projects/ogpextras/rss?path=/Alternative-Snapshot\&limit=3#g' "$OGP_WEB_PATH/modules/update/update.php"
	fi
	
	# Go back to original dir
	cd "$inDir"	
}

##---------------------------------------------##
## Main Implementation CODE START              ##
##---------------------------------------------##

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Install curl
aptgetInstall curl
if [ -z $(which curl) ]; then
	echo -e "\nPlease install curl before attempting to run this script!\n"
fi

clear
echo -e "----------------------------------\nOpen Game Panel Upgrader Script\n----------------------------------\nVersion 1.9\nUpdated: 5/14/2016\nBy OwN-3m-All (own3mall@gmail.com)\n\nThis script will create backups, update, and help you install the latest version of the Open Game Panel (OGP).\nIt handles both the web and agent installation scripts.\n\nThis is an upgrade script only! If you want to install OGP, go to http://www.opengamepanel.org for help!\n"
echo -n "Start the update process [y/n]: "
read startScript
startScript=$(echo "$startScript" | awk '{print tolower($0)}')

if [ ! -z "$startScript" ] && [ "$startScript" != "n" ]; then

  # Original directory
  ORIGDIR=$(pwd)
  
  # Install SVN
  echo -e "Installing subversion\n"
  aptgetInstall subversion
  
  # Check to make sure SVN is installed
  checkForSVN
  
  # Make current version backups
  service ogp_agent stop
  
  # Create directories if they don't exist needed by this script
  echo -e "Creating backup directories\n"
  createNeededDirs
  
  # Get OGP information
  echo -e "Prompting for OGP user variables\n"
  promptDirs
  
  # Get database information
  # The actual dump and backup occur later depending on update method selected
  echo -e "\nPrompting for MySQL data to create a backup of the OGP database\n"
  mysqldumpFile
  
  # Create a backup of the OGP agent files
  echo -e "\nCreating a backup of the agent files in $bkdirAgent\n"
  cd "$OGP_AGENT_PATH"
  # Get original ownership information
  if [ -e "ogp_agent.pl" ]; then
	 AGENTOWNER=$(ls -l "ogp_agent.pl" | awk '{print $3}')
  fi
  cp -R ./* "$bkdirAgent/tmp"
  
  # Create a backup of the OGP panel files
  echo -e "\nCreating a backup of the web panel files in $bkdirWeb\n"
  cd "$OGP_WEB_PATH"
  # Get original ownership information
  if [ -e "index.php" ]; then
	 WEBOWNER=$(ls -l "index.php" | awk '{print $3}')
  fi
  cp -R ./* "$bkdirWeb/tmp"
  
  # Create archives of backups and then delete directories
  cd "$bkdirAgent"
  if [ -e "tmp" ]; then
    tar -cvzf $(date +"%m_%d_%Y_%H%M%S")_OGP.tar.gz "tmp"
    rm -R "tmp"
  fi
  
  cd "$bkdirWeb"
  if [ -e "tmp" ]; then
    tar -cvzf $(date +"%m_%d_%Y_%H%M%S")_opengamepanel.tar.gz "tmp"
    
    # Don't delete the tmp files yet... we are going to import everything that doesn't already exist in the base install later
  fi
  
  # Backups completed #
  echo -e "\nNon-database backups completed successfully!"
  echo -e "\nRetrieving latest OGP version and beginning install procedures.  This may take a while since we're downloading files!\n"
  
  # Now get the latest version of OGP Agent and Web
  cd "$ogpdldir"
  rm -R ./*
  
  SVN_URL="svn://svn.code.sf.net/p/hldstart/svn/trunk"
  svn info ${SVN_URL}
  if [ $? -eq 1 ]; then
    echo "svn command failed: unable to access ${SVN_URL}";
    exit 1;
  fi
  
  performSVNCheckout
  
  rm -Rf trunk/.svn
  cd trunk
  cd agent
  
  # Print out information.
  echo -e "\nThe OGP agent install script is going to run."
  
  if [ ! -z "$ENCRYPTION_KEY" ]; then
	echo -e "\nFor your information, your current agent encryption key is: $ENCRYPTION_KEY"
	sleep 3
  fi
  
  # Try to automatically install the agent
  installAgent
  
  # This script assumes user is running apache... if not, the owner will be root
  # Can't assume this...
  # Get apache user
  # determineApacheUser
  
  service ogp_agent start
  
  # Install the web portion then continue the script
  finishInstall	
  
  echo -e "\nUpdate operations complete and successful!"

fi


