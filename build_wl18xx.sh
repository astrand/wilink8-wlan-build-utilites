export PATH__ROOT=`pwd`    
. configuration.sh    
. setup-env
# Pretty colors
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
NORMAL="\033[00m"
BLUE="\033[34m"
RED="\033[31m"
PURPLE="\033[35m"
CYAN="\033[36m"
UNDERLINE="\033[02m"

function print_highlight()
{      
    echo -e "   ${YELLOW}***** $1 ***** ${NORMAL} "
}

function usage ()
{
    echo ""
    echo "This script build all/one of the relevent wl18xx software package."
    echo ""
    echo "Usage : "
    echo ""
    echo "Building full package : Build all components except kernel,dtb "
    echo "        ./build_wl18xx.sh init         	   	[ Download and Update w/o build  ] "
    echo "                          update       R8.8        	[ Update to specific TAG & Build ] "
    echo "                          clean                    	[ Clean & Build                  ] "
    echo "                          check_updates            	[ Check for build script updates ] "
    echo ""
    echo "Building specific component :"
    echo "                          hostapd                  	[ Clean & Build hostapd          ] "
    echo "                          wpa_supplicant           	[ Clean & Build wpa_supplicant   ] "
    echo "                          modules                  	[ Clean & Build driver modules   ] "
    echo "                          firmware                 	[ Install firmware binary        ] "
    echo "                          scripts                  	[ Install scripts                ] "
    echo "                          utils                    	[ Clean & Build scripts          ] "
    echo "                          iw                       	[ Clean & Build iw               ] "
    echo "                          openssl                  	[ Clean & Build openssll         ] "
    echo "                          libnl                    	[ Clean & Build libnl            ] "
    echo "                          wireless-regdb           	[ Install wireless regdb   ] "
    echo "                          patch_kernel             	[ Apply provided kernel patches  ] "
    echo "                          kernel <defconfig filename> 	[ Clean & Build Kernel 	      ] "
    echo "                          kernel_noclean <defconfig_filename>  	[ Build Kernel w/o clean  ] "
    echo "                          patch_bbbe14_dts         	[Patch bbb black dts file to add e14 cape support] "
    echo "                          bbbe14_dtb               	[Build bbb device tree file with e14 cape support] "




    exit 1
}

function assert_no_error()
{
	if [ $? -ne 0 ]; then
		echo "****** ERROR $? $@*******"
		exit 1
	fi
        echo "****** $1 *******"
}

function repo_id()
{
	i="0"
	while [ $i -lt ${#repositories[@]} ]; do
		[ $1 == "${repositories[i]}" ] && echo $i
		i=$[$i + 3]
	done
}

function repo_url()
{
	echo "${repositories[`repo_id $1` + 1]}"
}

function repo_branch()
{
	echo "${repositories[`repo_id $1` + 2]}"
}

function path()
{
	i="0"
	while [ $i -lt "${#paths[@]}" ]; do
		[ $1 == "${paths[i]}" ] && echo "${paths[i + 1]}"
		i=$[$i + 2]
	done
}

function set_path()
{
	i="0"    
	while [ $i -lt "${#paths[@]}" ]; do
		[ $1 == "${paths[i]}" ] && paths[i+1]=$2    
		i=$[$i + 2]
	done
}

function repo_path()
{
	echo `path src`/$1
}

function cd_path()
{
	cd `path $1`
}

function cd_repo()
{
	cd `repo_path $1`
}

function cd_back()
{
	cd - > /dev/null
}

function check_for_build_updates()
{
        git fetch
        count=`git status -uno | grep behind | wc -l`
        if [ $count -ne 0 ]
        then
                echo ""
		echo "*** Please note, there is an updated build script avilalable ***"
		echo "*** Use 'git pull' to get the latest update. ***" 
		echo ""
		sleep 5
        fi
}

function read_kernel_version()
{
        filename=$KERNEL_PATH/Makefile
	VERSION_STRING="VERSION = "

        if [ ! -f $filename ]
        then
            KERNEL_VERSION=0
            KERNEL_PATCHLEVEL=0
            KERNEL_SUBLEVEL=0
            echo "No Makefile was found. Kernel version was set to default." 
        else 
            exec 6< $filename
	    read VERSION <&6
	    version_parse=$(echo $VERSION|sed 's/[0-9]\+$//')
	    while [ "$version_parse" != "${VERSION_STRING}" ]; do
		read VERSION <&6
		version_parse=$(echo $VERSION|sed 's/[0-9]\+$//')
	    done			

            read PATCHLEVEL <&6
            read SUBLEVEL <&6
            exec 6<&-

            KERNEL_VERSION=$(echo $VERSION|sed 's/[^0-9]//g')
            KERNEL_PATCHLEVEL=$(echo $PATCHLEVEL|sed 's/[^0-9]//g')
            KERNEL_SUBLEVEL=$(echo $SUBLEVEL|sed 's/[^0-9]//g')
            
	    echo "Makefile was found. Kernel version was set to $KERNEL_VERSION.$KERNEL_PATCHLEVEL.$KERNEL_SUBLEVEL." 
        fi
	[ $VERIFY_CONFIG ] && ./verify_kernel_config.sh $KERNEL_PATH/.config
}

#----------------------------------------------------------j
function setup_environment()
{
    print_highlight " *** Entering to create the setup environment based on setup-env file ....."
    if [ ! -e setup-env ]
    then
        echo "******** No setup-env file found !! Exiting the script ***********************"
        exit 1
    fi
    
    #if a rootfs path is set - replace the default.
    if [[ "$ROOTFS" != "DEFAULT" ]]
    then            
        echo " Changing ROOTFS path to $ROOTFS"
        set_path filesystem $ROOTFS
        [ ! -d $ROOTFS ] && echo "Error ROOTFS: $ROOTFS dir does not exist" && exit 1
    fi
 
    #if no toolchain path is set - exit 
    if [[ "$TOOLCHAIN_PATH" == "" ]]
    then            
        echo "Please set TOOLCHAIN_PATH in setupenv. Exiting !"
        exit 
    fi   


    #if no kernel path is set - exit
    if [[ "$KERNEL_PATH" == "" ]]
    then            
        echo "Please set KERNEL_PATH in setupenv. Exiting ! "
        exit 
    else 
        echo " Using user defined kernel"                        
        [ ! -d $KERNEL_PATH ] && echo "Error KERNEL_PATH: $KERNEL_PATH dir does not exist" && exit 1
    fi  
    
	export PROCESSORS_NUMBER=$(egrep '^processor' /proc/cpuinfo | wc -l)
	export PKG_CONFIG_PATH=`path filesystem`/lib/pkgconfig
	export INSTALL_PREFIX=`path filesystem`
	export LIBNL_PATH=`repo_path libnl`	
	export KLIB=`path filesystem`
	export KLIB_BUILD=${KERNEL_PATH}
	export PATH=$TOOLCHAIN_PATH:$PATH
    
}

function setup_filesystem_skeleton()
{
	mkdir -p `path filesystem`/usr/bin
	mkdir -p `path filesystem`/etc
	mkdir -p `path filesystem`/etc/init.d
	mkdir -p `path filesystem`/etc/rcS.d
	mkdir -p `path filesystem`/usr/lib/crda
	mkdir -p `path filesystem`/lib/firmware/ti-connectivity
	mkdir -p `path filesystem`/usr/share/wl18xx
	mkdir -p `path filesystem`/usr/sbin/wlconf
	mkdir -p `path filesystem`/usr/sbin/wlconf/official_inis
        mkdir -p `path filesystem`/etc/wireless-regdb/pubkeys
	mkdir -p `path filesystem`/boot
}

function setup_directories()
{
	i="0"
	while [ $i -lt ${#paths[@]} ]; do
		mkdir -p ${paths[i + 1]}
		i=$[$i + 2]
	done
	setup_filesystem_skeleton

}

function setup_repositories()
{
	i="0"
	while [ $i -lt ${#repositories[@]} ]; do
		url=${repositories[$i + 1]}
		name=${repositories[$i]}
        echo -e "${NORMAL}Cloning into: ${GREEN} $name ${NORMAL}"        
        #Skip kernel clone if it was user defined 
		[ "$name" != "kernel" -o "$DEFAULT_KERNEL" ] && [ ! -d `repo_path $name` ] && git clone $url `repo_path $name`
		i=$[$i + 3]
	done        
}

function setup_branches()
{
	i="0"    
	while [ $i -lt ${#repositories[@]} ]; do
		name=${repositories[$i]}
		url=${repositories[$i + 1]}
        branch=${repositories[$i + 2]}   
        checkout_type="branch"       
        #for all the openlink repo. we use a tag if provided.               
        [ "$name" == "kernel" ] && [ -z "$DEFAULT_KERNEL" ] && i=$[$i + 3] && continue
        cd_repo $name 	
        echo -e "\n${NORMAL}Checking out branch ${GREEN}$branch  ${NORMAL}in repo ${GREEN}$name ${NORMAL} "
		git checkout $branch        
        git fetch origin
        git fetch origin --tags  
        if [[ "$url" == *git.ti.com* ]]
        then            
           [[ -n $RESET ]] && echo -e "${PURPLE}Reset to latest in repo ${GREEN}$name ${NORMAL} branch  ${GREEN}$branch ${NORMAL}"  && git reset --hard origin/$branch
           [[ -n $USE_TAG ]] && git checkout $USE_TAG  && echo -e "${NORMAL}Reset to tag ${GREEN}$USE_TAG   ${NORMAL}in repo ${GREEN}$name ${NORMAL} "            
        fi        
		cd_back
		i=$[$i + 3]
	done
}

function build_zImage()
{
	if [ "$CLEAN_KERNEL" == "Y" ]|| [ "$CLEAN_KERNEL" == "y" ]
	then
		make -C $KERNEL_PATH ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE mrproper
	fi
	echo "Building Kernel"
        make -C $KERNEL_PATH ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE $1
        make -j ${PROCESSORS_NUMBER} -C $KERNEL_PATH ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE  zImage
        assert_no_error
        install -d `path filesystem`/boot
        cp  $KERNEL_PATH/arch/arm/boot/zImage `path filesystem`/boot
        cp  $KERNEL_PATH/vmlinux `path filesystem`/boot
        cp  $KERNEL_PATH/System.map `path filesystem`/boot
        assert_no_error
}

function patch_bbbe14_dts()
{
	cd $KERNEL_PATH    
	patch -p1  < $PATH__ROOT/patches/kernel_patches/beaglebone-wilink8-capes/Enable-TI-WiFi-Bluetooth-am335x-boneblack-WL1837.patch
	assert_no_error
	cd_back
}

function bbbe14_dtb()
{
        make -C $KERNEL_PATH ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j${PROCESSORS_NUMBER} am335x-boneblack.dtb
        cp  $KERNEL_PATH/arch/arm/boot/dts/am335x-boneblack.dtb `path filesystem`/boot
        assert_no_error

}

function build_modules()
{
        make -j 2 -C $KERNEL_PATH ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE  modules clean
	make -j 2 -C $KERNEL_PATH ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE  modules
	assert_no_error
        make -C $KERNEL_PATH ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=`path filesystem` INSTALL_MOD_STRIP=1 modules_install
	assert_no_error
	#cd_back
}

function build_openssl()
{
	cd_repo openssl
	[ -z $NO_CONFIG ] && ./Configure linux-generic32 --prefix=`path filesystem`/usr/local
	[ -z $NO_CLEAN ] && make clean
	[ -z $NO_CLEAN ] && assert_no_error
	make
	assert_no_error
	DESTDIR=`path filesystem` make install_sw
	assert_no_error
	cd_back
}


function build_iw()
{
	cd_repo iw
	[ -z $NO_CLEAN ] && make clean
	[ -z $NO_CLEAN ] && assert_no_error
	CC=${CROSS_COMPILE}gcc LIBS+=" -lpthread -lm" make V=1
	assert_no_error
	DESTDIR=`path filesystem` make install
	assert_no_error
	cd_back
}

function build_wreg()
{
        cd_repo wireless_regdb 
        DESTDIR=`path filesystem` make install
        assert_no_error
        cd_back
}


function build_libnl()
{
	cd_repo libnl
	[ -z $NO_CONFIG ] && ./autogen.sh
	[ -z $NO_CONFIG ] && ./configure --prefix=`path filesystem` --host=${ARCH} CC=${CROSS_COMPILE}gcc AR=${CROSS_COMPILE}ar
	([ -z $NO_CONFIG ] || [ -z $NO_CLEAN ]) && make clean
	[ -z $NO_CLEAN ] && assert_no_error
	make
	assert_no_error
	make install
	assert_no_error
	cd_back
}

function build_wpa_supplicant()
{
	cd `repo_path hostap`/wpa_supplicant
	[ -z $NO_CONFIG ] && cp android.config .config
    [ -n "$SYSLOG_EN" ] && echo "Enable DEBUG_SYSLOG config" && sed -i "/#CONFIG_DEBUG_SYSLOG=y/ s/# *//" .config
	CONFIG_LIBNL32=y DESTDIR=`path filesystem` make clean
	assert_no_error
	CONFIG_LIBNL32=y DESTDIR=`path filesystem` CFLAGS+="-I`path filesystem`/usr/local/ssl/include -I`path filesystem`/usr/local/include -I`repo_path libnl`/include" LIBS+="-L`path filesystem`/lib -L`path filesystem`/usr/local/lib -lssl -lcrypto -lm -ldl -lpthread" LIBS_p+="-L`path filesystem`/lib -L`path filesystem`/usr/local/ssl/lib -lssl -lcrypto -lm -ldl -lpthread" make -j${PROCESSORS_NUMBER} CC=${CROSS_COMPILE}gcc LD=${CROSS_COMPILE}ld AR=${CROSS_COMPILE}ar
	assert_no_error
	CONFIG_LIBNL32=y DESTDIR=`path filesystem` make install
	assert_no_error
	cd_back    
    cp `repo_path scripts_download`/conf/*_supplicant.conf  `path filesystem`/etc/
    sudo mv `path filesystem`/usr/local/sbin/wpa* `path filesystem`/usr/sbin
}

function build_hostapd()
{
    cd `repo_path hostap`/hostapd
	[ -z $NO_CONFIG ] && cp android.config .config
	[ -z $NO_UPNP ] && echo "Enable UPNP config" && sed -i "/#CONFIG_WPS_UPNP=y/ s/# *//" .config
	CONFIG_LIBNL32=y DESTDIR=`path filesystem` make clean
	assert_no_error
	CONFIG_LIBNL32=y DESTDIR=`path filesystem` CFLAGS+="-I`path filesystem`/usr/local/ssl/include  -I`path filesystem`/usr/local/include -I`repo_path libnl`/include" LIBS+="-L`path filesystem`/lib -L`path filesystem`/usr/local/lib -lssl -lcrypto -lm -ldl -lpthread" LIBS_p+="-L`path filesystem`/lib -L`path filesystem`/usr/local/lib -lssl -lcrypto -lm -ldl -lpthread" make -j${PROCESSORS_NUMBER} CC=${CROSS_COMPILE}gcc LD=${CROSS_COMPILE}ld AR=${CROSS_COMPILE}ar
	assert_no_error
	CONFIG_LIBNL32=y DESTDIR=`path filesystem` make install
	assert_no_error
	cd_back
    cp `repo_path scripts_download`/conf/hostapd.conf  `path filesystem`/etc/    
    sudo mv `path filesystem`/usr/local/bin/host* `path filesystem`/usr/sbin
}


function build_wl_logger()
{
	if [ -d "`repo_path ti_utils`/wl_logproxy" ]; then
	        cd `repo_path ti_utils`/wl_logproxy
		[ -z $NO_CLEAN ] && NFSROOT=`path filesystem` make clean
	        [ -z $NO_CLEAN ] && assert_no_error
		NLVER=3 NLROOT=`repo_path libnl`/include NFSROOT=`path filesystem` LIBS+=-lpthread make
	        assert_no_error
		NFSROOT=`path filesystem` make install
	        cd_back
	fi
}

function build_calibrator()
{
	cd_repo ti_utils
	[ -z $NO_CLEAN ] && NFSROOT=`path filesystem` make clean
	[ -z $NO_CLEAN ] && assert_no_error
	NLVER=3 NLROOT=`repo_path libnl`/include NFSROOT=`path filesystem` LIBS+=-lpthread make
	assert_no_error
	NFSROOT=`path filesystem` make install
	#assert_no_error
	cp -f `repo_path ti_utils`/hw/firmware/wl1271-nvs.bin `path filesystem`/lib/firmware/ti-connectivity
	cd_back
}

function build_wlconf()
{
	files_to_copy="dictionary.txt struct.bin default.conf wl18xx-conf-default.bin README example.conf example.ini configure-device.sh"
	cd `repo_path ti_utils`/wlconf
	if [ -z $NO_CLEAN ]; then
		NFSROOT=`path filesystem` make clean
		assert_no_error
		for file_to_copy in $files_to_copy; do
			rm -f `path filesystem`/usr/sbin/wlconf/$file_to_copy
		done
		rm -f `path filesystem`/usr/sbin/wlconf/official_inis/*
	fi
	NFSROOT=`path filesystem` make CC=${CROSS_COMPILE}gcc LD=${CROSS_COMPILE}ld
	assert_no_error

	# install
	cp -f `repo_path ti_utils`/wlconf/wlconf `path filesystem`/usr/sbin/wlconf
	chmod 755 `path filesystem`/usr/sbin/wlconf
	for file_to_copy in $files_to_copy; do
		cp $file_to_copy `path filesystem`/usr/sbin/wlconf/$file_to_copy
		echo "echoying files $file_to_copy"
	done
	cp official_inis/* `path filesystem`/usr/sbin/wlconf/official_inis/
	cd_back
}

function build_fw_download()
{
	cp `repo_path fw_download`/*.bin `path filesystem`/lib/firmware/ti-connectivity
}

function patch_kernel()
{

	[ ! -d $KERNEL_PATH ] && echo "Error KERNEL_PATH: $KERNEL_PATH dir does not exist" && exit 1
	echo "using kernel: $KERNEL_PATH"
	read_kernel_version

        read -p 'Kernel patches are based on Linux Kernel 4.19.38. Do you want to apply these patches to kernel mentioned in setupenv file  [y/n] : ' apply_patches

        case $apply_patches in
            "n") APPLY_KERNEL_PATCHES=0; echo "Patches NOT Applied, Exiting" ; exit;;
            "N") APPLY_KERNEL_PATCHES=0; echo "Patches NOT Applied, Exiting" ; exit;;
            "y") APPLY_KERNEL_PATCHES=1;;
            "Y") APPLY_KERNEL_PATCHES=1;;
            *) echo "Wrong Entry.Please enter y or n, Exiting ";APPLY_KERNEL_PATCHES=-1;exit;;
        esac
        echo "apply patches $APPLY_KERNEL_PATCHES"

        echo "$KERNEL_PATH \n $KERNEL_VARIANT \n $PATH__ROOT/patches/kernel_patches/$KERNEL_VARIANT \n "

        cd $KERNEL_PATH
        if [ $APPLY_KERNEL_PATCHES -eq 1 ] && [ -d "$PATH__ROOT/patches/kernel_patches/4.19.38" ]; then
                for i in $PATH__ROOT/patches/kernel_patches/4.19.38/*.patch; do
                        print_highlight "Applying driver patch: $i"
                        patch -p1 -N  < $i;
                        assert_no_error
                done
        fi
	
	assert_no_error
	cd_back
}

function build_scripts_download()
{
	cd_repo scripts_download
	echo "Copying scripts"
	scripts_download_path=`repo_path scripts_download`
	for script_dir in `ls -d $scripts_download_path`/*/
	do
		echo "Copying everything from ${script_dir} to `path filesystem`/usr/share/wl18xx directory"
		cp -rf ${script_dir}/* `path filesystem`/usr/share/wl18xx
	done
	cd_back
}


function clean_outputs()
{
    if [[ "$ROOTFS" == "DEFAULT" ]]
    then
        echo "Cleaning outputs"
        cp -r `path filesystem`/boot ./boot_temp
	rm -rf `path filesystem`/*
        cp -r ./boot_temp `path filesystem`/boot
	rm -r boot_temp

    fi
}


function set_files_to_verify()
{
        files_to_verify=(
        # skeleton path
        # source path
        # pattern in output of file

        `path filesystem`/usr/sbin/wpa_supplicant
        `repo_path hostap`/wpa_supplicant/wpa_supplicant
        "ELF 32-bit LSB[ ]*executable, ARM"

        `path filesystem`/usr/sbin/hostapd
        `repo_path hostap`/hostapd/hostapd
        "ELF 32-bit LSB[ ]*executable, ARM"

        `path filesystem`/usr/lib/crda/regulatory.bin
        `repo_path wireless_regdb`/regulatory.bin
        "CRDA wireless regulatory database file"

        `path filesystem`/lib/firmware/ti-connectivity/wl18xx-fw-4.bin
        `repo_path fw_download`/wl18xx-fw-4.bin
        "data"

        `path filesystem`/lib/modules/$KERNEL_VERSION.$KERNEL_PATCHLEVEL.*/kernel/drivers/net/wireless/ti/wl18xx/wl18xx.ko
        `path filesystem`/lib/modules/$KERNEL_VERSION.$KERNEL_PATCHLEVEL.*/kernel/drivers/net/wireless/ti/wl18xx/wl18xx.ko

        "ELF 32-bit LSB[ ]*relocatable, ARM"

        `path filesystem`/lib/modules/$KERNEL_VERSION.$KERNEL_PATCHLEVEL.*/kernel/drivers/net/wireless/ti/wlcore/wlcore.ko
        `path filesystem`/lib/modules/$KERNEL_VERSION.$KERNEL_PATCHLEVEL.*/kernel/drivers/net/wireless/ti/wlcore/wlcore.ko

        "ELF 32-bit LSB[ ]*relocatable, ARM"

        #`path filesystem`/usr/bin/calibrator
        #`repo_path ti_utils`/calibrator
        #"ELF 32-bit LSB[ ]*executable, ARM"

        `path filesystem`/usr/sbin/wlconf/wlconf
        `repo_path ti_utils`/wlconf/wlconf
        "ELF 32-bit LSB[ ]*executable, ARM"
        )
}

function get_tag()
{
       i="0"
       while [ $i -lt ${#repositories[@]} ]; do
               name=${repositories[$i]}
               url=${repositories[$i + 1]}
        branch=${repositories[$i + 2]}
        checkout_type="branch"
        cd_repo $name
        if [[ "$url" == *git.ti.com* ]]
        then
                echo -e "${PURPLE}Describe of ${NORMAL} repo : ${GREEN}$name ${NORMAL} "  ;
                git describe --tag
        fi
               cd_back
               i=$[$i + 3]
       done
}



function admin_tag()
{
	i="0"    
	while [ $i -lt ${#repositories[@]} ]; do
		name=${repositories[$i]}
		url=${repositories[$i + 1]}
        branch=${repositories[$i + 2]}   
        checkout_type="branch"              
        cd_repo $name    
        if [[ "$url" == *git.ti.com* ]]
        then                                   
                echo -e "${PURPLE}Adding tag ${GREEN} $1 ${NORMAL} to repo : ${GREEN}$name ${NORMAL} "  ;
                git show --summary        
                read -p "Do you want to tag this commit ?" yn
                case $yn in
                    [Yy]* )  git tag -a $1 -m "$1" ;
                             git push --tags ;;
                    [Nn]* ) echo -e "${PURPLE}Tag was not applied ${NORMAL} " ;;
                    
                    * ) echo "Please answer yes or no.";;
                esac
           
        fi        
		cd_back
		i=$[$i + 3]
	done
}


function verify_skeleton()
{
	echo "Verifying filesystem skeleton..."

        set_files_to_verify

	i="0"
	while [ $i -lt ${#files_to_verify[@]} ]; do
		skeleton_path=${files_to_verify[i]}
		source_path=${files_to_verify[i + 1]}
		file_pattern=${files_to_verify[i + 2]}
		file $skeleton_path | grep "${file_pattern}" >/dev/null
        if [ $? -eq 1 ]; then
        echo -e "${RED}ERROR " $skeleton_path " Not found ! ${NORMAL}"
        #exit
        fi

		md5_skeleton=$(md5sum $skeleton_path | awk '{print $1}')
		md5_source=$(md5sum $source_path     | awk '{print $1}')
		if [ $md5_skeleton != $md5_source ]; then
			echo "ERROR: file mismatch"
			echo $skeleton_path
			exit 1
		fi
		i=$[$i + 3]
	done
: '
	which regdbdump > /dev/null
	if [ $? -eq 0 ]; then
		regdbdump `path filesystem`/usr/lib/crda/regulatory.bin > /dev/null
		if [ $? -ne 0 ]; then
       			echo "Please update your public key used to verify the DB"
       		fi
	fi
'
}

function verify_installs()
{
    apps_to_verify=(
     libtool     
     python-m2crypto
     bison
     flex
    )

    i="0"
	while [ $i -lt ${#apps_to_verify[@]} ]; do
        if !( dpkg-query -s ${apps_to_verify[i]} 2>/dev/null | grep -q ^"Status: install ok installed"$ )then
            echo  "${apps_to_verify[i]} is missing"
            echo  "Please use 'sudo apt-get install ${apps_to_verify[i]}'"
            read -p "Do you want to install it now [y/n] ? (requires sudo) " yn
            case $yn in
                [Yy]* )  sudo apt-get install ${apps_to_verify[i]} ;;
                [Nn]* ) echo -e "${PURPLE}${apps_to_verify[i]} was not installed. leaving build. ${NORMAL} " ; exit 0 ;;
                * ) echo "Please answer y or n.";;
            esac
        fi
        i=$[$i + 1]
    done
}

function setup_workspace()
{
	setup_directories	
	setup_repositories
	setup_branches
        verify_installs
}


function build_all()
{
        build_openssl
        build_libnl
        build_wreg
        build_modules
        build_iw
        build_wpa_supplicant
        build_hostapd	
        build_calibrator
        build_wl_logger
        build_wlconf
        build_fw_download
        build_scripts_download
    
    [ -z $NO_VERIFY ] && verify_skeleton
}

function setup_and_build()
{
    setup_workspace
    build_all
}

function main()
{
	[[ "$1" == "-h" || "$1" == "--help"  ]] && usage
    setup_environment
    setup_directories
    read_kernel_version
    
	case "$1" in
        'init')                
        print_highlight " initializing workspace (w/o build) "       
		[[  -n "$2" ]] && echo "Using tag $2 " && USE_TAG=$2                
        NO_BUILD=1 
        setup_workspace
        read_kernel_version #####read kernel version again after init#####
		;;
              
        'clean')        
        print_highlight " cleaning & building all "       
        clean_outputs
        setup_directories
        build_all        
		;;

        'update')
        print_highlight " setting up workspace and building all "
		if [  -n "$2" ]
        then
            print_highlight "Using tag $2 "
            USE_TAG=$2
        else
            print_highlight "Updating all to head (this will revert local changes)"
            RESET=1
        fi
        #clean_kernel
        clean_outputs
        setup_workspace
        read_kernel_version #####read kernel version again after update#####
        [[ -z $NO_BUILD ]] && build_all
		;;

        #################### Building single components #############################
		'kernel')
		print_highlight " building only Kernel "
                CLEAN_KERNEL="Y" 
		build_zImage $2
		;;

        	'kernel_noclean')
        	print_highlight " building kernel without cleaning "
		CLEAN_KERNEL="N"
        	build_zImage $2
		;;
		
		'patch_bbbe14_dts')
		print_highlight " patching beagblebone black dts file to include support for e14 wireless cape"
		patch_bbbe14_dts
		;;

		'bbbe14_dtb')
		print_highlight " building beaglebone black device tree file with e14 wireless cape support "
		bbbe14_dtb
		;;

		'modules')
                print_highlight " building only Driver modules "
		build_modules
		;;

		'wpa_supplicant')
                print_highlight " building only wpa_supplicant "
		build_wpa_supplicant      
		;;

		'hostapd')
                print_highlight " building only hostapd "
		build_hostapd
		;;

		'wireless-regdb')
		print_highlight " building only wireless regulatory database "
		build_wreg
		;;
        
		'libnl')
		print_highlight " building only libnl"
		build_libnl
		;;

		'iw')
		print_highlight " building only iw"
		build_iw
		;;

		'openssl')
		print_highlight " building only openssl"
		build_openssl
		;;

		'scripts')
		print_highlight " Copying scripts "
		build_scripts_download
		;;

		'utils')
		print_highlight " building only ti-utils "
		build_calibrator
		build_wl_logger
		build_wlconf		
		;;

		'all_hostap')
                print_highlight " building hostap and dependencies "
                build_openssl
		build_libnl
                build_wpa_supplicant
		build_hostapd
                ;; 

		'firmware')
		print_highlight " building only firmware"
		build_fw_download
		;;

		'patch_kernel')
		print_highlight " only patching kernel $2 without performing an actual build!"
		NO_BUILD=1
		patch_kernel
		;;

        ############################################################
        'get_tag')
        get_tag
        exit
        ;;
		
        'admin_tag')        
		admin_tag $2
		;;

        'check_updates')
		check_for_build_updates
		;;

        *)
        echo " "
        echo "**** Unknown parameter - please see usage below **** "
        usage
        ;;
	esac
	
	echo "Wifi Package Build Successful"
}
main $@
