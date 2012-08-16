#!/usr/bin/perl
use strict;
use Cwd;

$ENV{'PWD'} = getcwd();

# does_It_Have( $arg1, $arg2 )
# does the string $arg1 have $arg2 in it ??
sub does_It_Have{
	my ($string, $target) = @_;
	if( $string =~ /$target/ ){
		return 1;
	};
	return 0;
};



#################### APP SPECIFIC PACKAGES INSTALLATION ##########################

my @ip_lst;
my @distro_lst;
my @version_lst;
my @arch_lst;
my @source_lst;
my @roll_lst;

my %cc_lst;
my %sc_lst;
my %nc_lst;

my $clc_index = -1;
my $cc_index = -1;
my $sc_index = -1;
my $ws_index = -1;

my $clc_ip = "";
my $cc_ip = "";
my $sc_ip = "";
my $ws_ip = "";

my $nc_ip = "";

my $max_cc_num = 0;

$ENV{'EUCALYPTUS'} = "/opt/eucalyptus";

my $bzr_branch = "main-equallogic";
my $arch = "64";

my $script_2_use = "iscsidev.sh";

#### read the input list

my $index = 0;

my $is_memo;
my $memo = "";

open( LIST, "../input/2b_tested.lst" ) or die "$!";
my $line;
while( $line = <LIST> ){
	chomp($line);

	if( $is_memo ){
		if( $line ne "END_MEMO" ){
			$memo .= $line . "\n";
		};
	};

	if( $line =~ /^([\d\.]+)\t(.+)\t(.+)\t(\d+)\t(.+)\t\[([\w\s\d]+)\]/ ){
		print "IP $1 with $2 distro was built from $5 as Eucalyptus-$6\n";

		if( !( $2 eq "VMWARE" || $2 eq "WINDOWS" ) ){

			push( @ip_lst, $1 );
			push( @distro_lst, $2 );
			push( @version_lst, $3 );
			push( @arch_lst, $4 );
			push( @source_lst, $5 );
			push( @roll_lst, $6 );

			$arch = $4;
			my $this_roll = $6;

			if( does_It_Have($this_roll, "CLC") && $clc_ip eq "" ){
				$clc_index = $index;
				$clc_ip = $1;
			};

			if( does_It_Have($this_roll, "CC") ){
				$cc_index = $index;
				$cc_ip = $1;

				if( $this_roll =~ /CC(\d+)/ ){
					$cc_lst{"CC_$1"} = $cc_ip;
					if( $1 > $max_cc_num ){
						$max_cc_num = $1;
					};
				};			
			};

			if( does_It_Have($this_roll, "SC") ){
				$sc_index = $index;
				$sc_ip = $1;

				if( $this_roll =~ /SC(\d+)/ ){
	                                $sc_lst{"SC_$1"} = $sc_ip;
	                        };
			};

			if( does_It_Have($this_roll, "WS") ){
	                        $ws_index = $index;
	                        $ws_ip = $1;
	                };

			if( does_It_Have($this_roll, "NC") ){
	                        #$nc_ip = $nc_ip . " " . $1;
				$nc_ip = $1;
				if( $this_roll =~ /NC(\d+)/ ){
					if( $nc_lst{"NC_$1"} eq	 "" ){
	                                	$nc_lst{"NC_$1"} = $nc_ip;
					}else{
						$nc_lst{"NC_$1"} = $nc_lst{"NC_$1"} . " " . $nc_ip;
					};
	                        };
	                };

			$index++;

		};

        }elsif( $line =~ /^BZR_BRANCH\s+(.+)/ ){
		$line = $1;
		if( $line =~ /\/eucalyptus\/(.+)/ ){
			$bzr_branch = $1;
		};
	}elsif( $line =~ /^MEMO/ ){
		$is_memo = 1;
	}elsif( $line =~ /^END_MEMO/ ){
		$is_memo = 0;
	};

};

close( LIST );

$ENV{'QA_MEMO'} = $memo;

if( $clc_ip eq "" ){
	print "Could not find the IP of CLC\n";
};

if( $cc_ip eq "" ){
        print "Could not find the IP of CC\n";
};

if( $sc_ip eq "" ){
        print "Could not find the IP of SC\n";
};

if( $ws_ip eq "" ){
        print "Could not find the IP of WS\n";
};

if( $nc_ip eq "" ){
        print "Could not find the IP of NC\n";
};


chomp($nc_ip);

my $san_provider = "NULL";
if( is_san_provider_from_memo() == 1 ){
	$san_provider = $ENV{'QA_MEMO_SAN_PROVIDER'};
};

for( my $i = 0; $i < @ip_lst; $i++ ){
	my $this_ip = $ip_lst[$i];
	my $this_distro = $distro_lst[$i];
	my $this_version = $version_lst[$i];
	my $this_source = $source_lst[$i];
	my $this_roll = $roll_lst[$i];
	my $stripped_roll = strip_num($this_roll);


	###	ADDED 8/8/12 for VNX Support
	if( $san_provider eq "EmcVnxProvider" ){
		if( ($this_distro eq "RHEL" || $this_distro eq "CENTOS") && $this_version =~ /^6\./ && does_It_Have($stripped_roll, "SC") ){
			print "$this_ip : Setting up VNX CLI TOOL on Storage-Controller\n"; 
		
			print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"wget qa-server/4qa/vnx/navicli-linux-64-x86-en_us-7.30.15.0.44-1.x86_64.rpm\"\n");
			system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"wget qa-server/4qa/vnx/navicli-linux-64-x86-en_us-7.30.15.0.44-1.x86_64.rpm\" ");
			sleep(1);

			print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"yum -y install navicli-linux-64-x86-en_us-7.30.15.0.44-1.x86_64.rpm\"\n");
			system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"yum -y install navicli-linux-64-x86-en_us-7.30.15.0.44-1.x86_64.rpm\" ");

		};
	};


	if( $this_source eq "PACKAGE" || $this_source eq "REPO" ){

		$ENV{'EUCALYPTUS'} = "";
		###	DO NOTHING... Package install should take care of all the below ops.

	}else{

		$ENV{'EUCALYPTUS'} = "/opt/eucalyptus";

		if( does_It_Have($stripped_roll, "SC") || does_It_Have($stripped_roll, "NC") ){
			print "$this_ip : Setting up SAN on Storage-Controller\n"; 
		
			# copy the 55-openiscsi.rules to /etc/udev/rules
#			print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"cp $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/udev/55-openiscsi.rules /etc/udev/rules.d/. \"\n");
#			system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"cp $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/udev/55-openiscsi.rules /etc/udev/rules.d/. \" ");

			###	Changed to 55-openiscsi*		061412
			print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"cp $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/udev/55-openiscsi* /etc/udev/rules.d/. \"\n");
			system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"cp $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/udev/55-openiscsi* /etc/udev/rules.d/. \" ");

			###	FOR UBUNTU AND CENTOS/RHEL 5, use legacy rules	061412
			if( $this_distro eq "UBUNTU" || $this_distro eq "DEBIAN" ){
				if( $this_version eq "LUCID" ){
					print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"mv -f /etc/udev/rules.d/55-openiscsi-legacy.rules /etc/udev/rules.d/55-openiscsi.rules\"\n");
					system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"mv -f /etc/udev/rules.d/55-openiscsi-legacy.rules /etc/udev/rules.d/55-openiscsi.rules\" ");
				};
                       }elsif( $this_distro eq "CENTOS" || $this_distro eq "RHEL" ){
				if( $this_version =~ /^5/ ){
					print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"mv -f /etc/udev/rules.d/55-openiscsi-legacy.rules /etc/udev/rules.d/55-openiscsi.rules\"\n");
					system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"mv -f /etc/udev/rules.d/55-openiscsi-legacy.rules /etc/udev/rules.d/55-openiscsi.rules\" ");
				};
			};


			###	ONE SCRIPT TO RULE THEM ALL		061412
			$script_2_use = "iscsidev.sh";
			
#			if( $this_distro eq "UBUNTU" || $this_distro eq "DEBIAN" ){ 
#				$script_2_use = "iscsidev-ubuntu.sh";
#			}elsif( $this_distro eq "OPENSUSE" ){
#				$script_2_use = "iscsidev-opensuse.sh";
#			}elsif( $this_distro eq "CENTOS" || $this_distro eq "FEDORA" || $this_distro eq "RHEL" ){
#				$script_2_use = "iscsidev-centos.sh";
#			};

			# copy the iscsidev-*.sh to /etc/udev/script
			print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"mkdir -p /etc/udev/scripts/ \"\n");
			system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"mkdir -p /etc/udev/scripts/ \" ");

			print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"cp $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/udev/$script_2_use /etc/udev/scripts/iscsidev.sh \"\n");
			system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"cp $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/udev/$script_2_use /etc/udev/scripts/iscsidev.sh \" ");

			#chmod
			print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"chmod +x /etc/udev/scripts/iscsidev.sh \"\n");
        	        system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"chmod +x /etc/udev/scripts/iscsidev.sh \" ");

			if( is_before_dual_repo() == 1 ){					### ADDED 052312
				if( $this_distro eq "UBUNTU" || $this_distro eq "DEBIAN" ){
					#udevamd control --reload-rules
					print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"udevadm control --reload-rules \"\n");
		        	        system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"udevadm control --reload-rules \" ");
				}else{
					#udevamd control --reload-rules
					print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"udevcontrol reload_rules\"\n");
		        	        system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"udevcontrol reload_rules\" ");
				};
			};

			if( is_mod_sudoers_for_ebs_from_memo() == 1 ){
				# mod sudoers
				if( does_It_Have($stripped_roll, "SC") ){
					print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/connect_iscsitarget_sc.pl\" >> /etc/sudoers\" \n");
					system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/connect_iscsitarget_sc.pl\" >> /etc/sudoers\" ");

        	        		print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/disconnect_iscsitarget_sc.pl\" >> /etc/sudoers\" \n");
					system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/disconnect_iscsitarget_sc.pl\" >> /etc/sudoers\" ");

				}else{
					print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/connect_iscsitarget.pl\" >> /etc/sudoers\" \n");
	                	        system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/connect_iscsitarget.pl\" >> /etc/sudoers\" ");

	                	        print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/disconnect_iscsitarget.pl\" >> /etc/sudoers\" \n");
	                	        system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/disconnect_iscsitarget.pl\" >> /etc/sudoers\" ");

	                	        print("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/get_iscsitarget.pl\" >> /etc/sudoers\" \n");
	                	        system("ssh -o StrictHostKeyChecking=no root\@$this_ip \"echo \"eucalyptus ALL=NOPASSWD: $ENV{'EUCALYPTUS'}/usr/share/eucalyptus/get_iscsitarget.pl\" >> /etc/sudoers\" ");
				};

			};		
		};
	};
};

exit(0);


1;


sub strip_num{
        my ($str) = @_;
        $str =~ s/\d//g;
        return $str;
};


sub is_mod_sudoers_for_ebs_from_memo{
	if( $ENV{'QA_MEMO'} =~ /MOD_SUDOERS_FOR_EBS=YES/ ){
		print "FOUND in MEMO\n";
		print "MOD_SUDOERS_FOR_EBS=YES\n";
		$ENV{'QA_MEMO_MOD_SUDOERS_FOR_EBS'} = "YES";
		return 1;
	};
	return 0;
};

sub is_euca_version_from_memo{
        if( $ENV{'QA_MEMO'} =~ /^EUCA_VERSION=(.+)\n/m ){
                my $extra = $1;
                $extra =~ s/\r//g;
                print "FOUND in MEMO\n";
                print "EUCA_VERSION=$extra\n";
                $ENV{'QA_MEMO_EUCA_VERSION'} = $extra;
                return 1;
        };
        return 0;
};

sub is_before_dual_repo{
	if( is_euca_version_from_memo() ){
		if( $ENV{'QA_MEMO_EUCA_VERSION'} =~ /^2/ || $ENV{'QA_MEMO_EUCA_VERSION'} =~ /^3\.0/ ){
			return 1;
		};
	};
	return 0;
};  

sub is_san_provider_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^SAN_PROVIDER=(.+)\n/m ){
		my $extra = $1;
		$extra =~ s/\r//g;
		print "FOUND in MEMO\n";
		print "SAN_PROVIDER=$extra\n";
		$ENV{'QA_MEMO_SAN_PROVIDER'} = $extra;
		return 1;
	};
	return 0;
};



1;




