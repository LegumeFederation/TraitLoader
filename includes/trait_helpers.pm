#!/usr/bin/perl

##############################################################################
# Author       : Ethy Cannon 
#                NOTE: developed from scripts written by Taein Lee 
#                      in the Main Lab.
# Target       : Generic loader for QTL/Map/Marker data
# Name         : trait_helpers.pm
# Date         : November, 2015
# Description  : Utility scripts for perl trail loaders
##############################################################################

use strict;
use Data::Dumper;

our $pg_db;
our $data_info_ref;

#------------------------------------------------#
# init_helper_module
#------------------------------------------------#
sub init_helper_module {
	my ($db_ref)= @_;
	
	# set database handler
	$pg_db = $db_ref;
}#init_helper_module

#-----------------------------------------------------------------------------#
# get_cv_id
#-----------------------------------------------------------------------------#
sub get_cv_id {
  my ($cv_name) = @_;
  $cv_name = $pg_db->trim($cv_name);
  return $pg_db->query_field("SELECT cv_id FROM cv WHERE LOWER(name) = LOWER('$cv_name')");
}


#-----------------------------------------------------------------------------#
# get_db_id
#-----------------------------------------------------------------------------#
sub get_db_id {
  my ($db_name) = @_;
  return $pg_db->query_field("SELECT db_id FROM db WHERE LOWER(name) = LOWER('$db_name')");
}


#-----------------------------------------------------------------------------#
# println : print on screen and/or LOG
#-----------------------------------------------------------------------------#
sub println {
  my ($string, $code)= @_;
  
  $code= trim($code);
  if ($code) {
    print LOG "$string\n";
  }
  else {
    # print out on screen if no code specified
    print "$string\n";
  }
}


#-----------------------------------------------------------------------------#
# readConfigFile()
# Read the contents of the configuration file.
#-----------------------------------------------------------------------------#
sub readConfigFile {
  my %config;
  
  open CONFIG, "<trait_loader.conf";
  while (<CONFIG>) {
    next if (/^#/);   # skip comments
    next if (!(/=/)); # skip lines that lack an '='
    chomp;chomp;
    
    my ($key, $value) = split(/=/, $_, 2);
    $config{trim($key)} = trim($value);
  }
  close CONFIG;
  
  return \%config;
}#readConfigFile


#TODO: small string cleanup functions including trim() are defined in 
#      PG_Database.pm, but require a PG_database object to access. But we
#      need to read config file before the PG_database object can be created
#      Moving these frequently-used functions out of PG_database to here will 
#      require changing lots of code.
#-----------------------------------------------------------------------------#
# trim()
# Trim whitespace from beginning and end of string.
#-----------------------------------------------------------------------------#
sub trim {
  my $str = $_[0];
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  return $str;
}#trim

1;
__END__
