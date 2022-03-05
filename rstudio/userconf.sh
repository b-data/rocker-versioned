#!/usr/bin/with-contenv bash

## Set defaults for environmental variables in case they are undefined
USER=${USER:=rstudio}
PASSWORD=${PASSWORD:=rstudio}
USERID=${USERID:=1000}
GROUPID=${GROUPID:=1000}
ROOT=${ROOT:=FALSE}
UMASK=${UMASK:=022}

bold=$(tput bold)
normal=$(tput sgr0)

if [[ ${DISABLE_AUTH,,} == "true" ]]
then
	mv /etc/rstudio/disable_auth_rserver.conf /etc/rstudio/rserver.conf
	echo "USER=$USER" >> /etc/environment
fi

if grep --quiet "auth-none=1" /etc/rstudio/rserver.conf
then
	echo "Skipping authentication as requested"
elif [ "$PASSWORD" == "rstudio" ]
then
    printf "\n\n"
    tput bold
    printf "\e[31mERROR\e[39m: You must set a unique PASSWORD (not 'rstudio') first! e.g. run with:\n"
    printf "docker run -e PASSWORD=\e[92m<YOUR_PASS>\e[39m -p 8787:8787 rocker/rstudio\n"
    tput sgr0
    printf "\n\n"
    exit 1
fi

if [ "$USERID" -lt 1000 ]
# Probably a macOS user, https://github.com/rocker-org/rocker/issues/205
  then
    echo "$USERID is less than 1000"
    check_user_id=$(grep -F "auth-minimum-user-id" /etc/rstudio/rserver.conf)
    if [[ ! -z $check_user_id ]]
    then
      echo "minumum authorised user already exists in /etc/rstudio/rserver.conf: $check_user_id"
    else
      echo "setting minumum authorised user to 499"
      echo auth-minimum-user-id=499 >> /etc/rstudio/rserver.conf
    fi
fi

if [ "$USERID" -ne 1000 ]
## Configure user with a different USERID if requested.
  then
    echo "deleting user rstudio"
    userdel rstudio
    echo "creating new $USER with UID $USERID"
    useradd -m $USER -u $USERID
    mkdir /home/$USER
    chown -R $USER /home/$USER
    usermod -a -G staff $USER
elif [ "$USER" != "rstudio" ]
  then
    ## cannot move home folder when it's a shared volume, have to copy and change permissions instead
    cp -r /home/rstudio /home/$USER
    ## RENAME the user
    usermod -l $USER -d /home/$USER rstudio
    groupmod -n $USER rstudio
    usermod -a -G staff $USER
    chown -R $USER:$USER /home/$USER
    echo "USER is now $USER"
fi

if [ "$GROUPID" -ne 1000 ]
## Configure the primary GID (whether rstudio or $USER) with a different GROUPID if requested.
  then
    echo "Modifying primary group $(id $USER -g -n)"
    groupmod -g $GROUPID $(id $USER -g -n)
    echo "Primary group ID is now custom_group $GROUPID"
fi

## Add a password to user
echo "$USER:$PASSWORD" | chpasswd

# Use Env flag to know if user should be added to sudoers
if [[ ${ROOT,,} == "true" ]]
  then
    adduser $USER sudo && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
    echo "$USER added to sudoers"
fi

## Change Umask value if desired
if [ "$UMASK" -ne 022 ]
  then
    echo "server-set-umask=false" >> /etc/rstudio/rserver.conf
    echo "Sys.umask(mode=$UMASK)" >> /home/$USER/.Rprofile
fi

## Next one for timezone setup
if [ "$TZ" !=  "Etc/UTC" ]
  then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
fi

## Set environment variable PANDOC_VERSION
PANDOC_VERSION=$(pandoc --version 2>/dev/null | head -n 1 | grep -oP '[\d\.]+$')
echo "$PANDOC_VERSION" >> /var/run/s6/container_environment/PANDOC_VERSION

## Set our dynamic variables in Renviron.site to be reflected by RStudio
exclude_vars="HOME PASSWORD"
for file in /var/run/s6/container_environment/*
do
  sed -i "/^${file##*/}=/d" /usr/local/lib/R/etc/Renviron.site
  regex="(^| )${file##*/}($| )"
  [[ ! $exclude_vars =~ $regex ]] && echo "${file##*/}=$(cat $file)" >> /usr/local/lib/R/etc/Renviron.site || echo "skipping $file"
done

## Update Locale if needed
if [ "$LANG" !=  "en_US.UTF-8" ]
  then
    /usr/sbin/locale-gen --lang $LANG
    /usr/sbin/update-locale --reset LANG=$LANG
fi

## only file-owner (root) should read container_environment files:
chmod 600 /var/run/s6/container_environment/*
