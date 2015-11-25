#!/usr/bin/perl

##############################################################################
# Author      : Ethy Cannon 
#               NOTE: developed from scripts written by Taein Lee 
#                     in the Main Lab.
# Target      : Generic loader for QTL/Map/Marker data
# Name        : trait_loader.pl
# Purpose     : Master script for loading QTL/Map/Marker data from spreadsheets.
# Date        : November, 2015
# Description  : 
# <input>      : <data_sheet>.xls (Excel 97-2004 format)
# <output>    : log
# Dependencies:  Configuration file, trait_loader.conf
#               Chado db schema 
#               Postgres 
#               Perl modules Spreadsheet::ParseExcel, Carp
# Usage       : perl trait_loader.pl <data_sheet>.xls
#
# --------------------------------------------------------
#  1. pre-processing
#   - read configuration file
#    - open files (excel and logs)
#    - connect database
#
#  2. processing excel sheets
#    - verify and load data in excel file into database
#
#  3. post-processing
#    - commit database transaction
#   - close files (excel and logs)
#    - disconnect database
#
###############################################################################

use strict;
use Carp;
use DBI;
use Spreadsheet::ParseExcel;
use Encode;
use File::Basename;
use Data::Dumper;

use lib qw(./includes);
use PG_Database;
use trait_helpers;

use lib qw(./loaders);
use load_contact;
use load_marker;

use lib qw(./verifiers);
use verify_contact;
use verify_marker;


# Get command line parameters
my $warn = <<EOS
  Usage:
    $0 excel-spreadsheet
EOS
;
die $warn if ($#ARGV < 0);

# The spreadsheet file name and path
my $excel = $ARGV[0];

# global variables
our $pg_db;
our $pub_id_ref;
my $config;
my $loghandle;
my $data_info_ref;

# Initialize stuff, open the excel spreadsheet
my ($start_time, $loaders_ref, $oBook) = preprocess();

# Call each loader by worksheet
if (verify_contact($pg_db, $oBook, $loaders_ref->{'contact'}, $data_info_ref)) {
  process_contact($pg_db, $oBook, $loaders_ref->{'contact'}, $data_info_ref);
}
if (verify_marker($pg_db, $oBook, $loaders_ref->{'marker'}, $data_info_ref)) {
  process_marker($pg_db, $oBook, $loaders_ref->{'marker'}, $data_info_ref);
}
  
# Cleanup and go home
postprocess($oBook, $start_time);


###############################################################################
#########################          FUNCTIONS          #########################
###############################################################################

#-----------------------------------------------------------------------------#
# get_cvs
#
# Checks that data dictionary cvterms and required ontologies have been loaded
#    and sets their cv_ids for future use.
# Required cvs indicated by the 'trait_ontology' setting in the configuration
#    file. 
#-----------------------------------------------------------------------------#
sub get_cvs {
  my ($data_info_ref, $config)= @_;
  
  # Error checking
  if (!$config->{'trait_ontology'}) {
    print "ERROR: No trait ontologies specified in the configuration file. \n";
    print "       There must be at least one trait ontology. Example: \n";
    print "           trait_ontologies = SOY \n";
    print "program terminated\n\n";
    exit;
  }
  
  # get db and cv record ids
  $data_info_ref->{'DB_ID'}      = get_db_id($data_info_ref->{'DB_NAME'});
  $data_info_ref->{'CV_ID'}      = get_cv_id($data_info_ref->{'CV_NAME'});
  $data_info_ref->{'CV_ID_RO'}   = get_cv_id('relationship');
  $data_info_ref->{'CV_ID_SO'}   = get_cv_id('sequence');
  $data_info_ref->{'CV_ID_TO'}   = get_cv_id( $config->{'trait_ontology'});
  $data_info_ref->{'CV_ID_TPUB'} = get_cv_id('tripal_pub');
  
  if ($config->{'trait_descriptor_ontology'}) {
    $data_info_ref->{'CV_ID_TD'} = get_cv_id($config->{'trait_descriptor_ontology'});
  }
  
  print "\n\n\t===============================\n\tCVs in cv table\n";
  print "\t-------------------------------\n";
  print "\t> MAIN                  : ".$data_info_ref->{'DB_ID'}."\n";
  print "\t> Relationship Ontology : ".$data_info_ref->{'CV_ID_RO'}."\n";
  print "\t> Sequence Ontology     : ".$data_info_ref->{'CV_ID_SO'}."\n";
  print "\t> Trait Descriptor      : ".$data_info_ref->{'CV_ID_TD'}."\n";
  print "\t> Trait Ontology        : ".$data_info_ref->{'CV_ID_TO'}."\n";
  print "\t-------------------------------\n\n";
  
  # check data_info
  foreach my $key (keys %{$data_info_ref}) {
    if (!$data_info_ref->{$key}) {
      print "\tERROR: data_info{".$key."} is empty\n";
      print "\tprogram terminated\n\n\n";
      exit;
    }
  }
}#get_cvs


#-----------------------------------------------------------#
# get_data_info
# Set the source of data
#  DB_NAME    : name of data dictionary database record
#  CV_NAME    : name of data dictionary cv record 
#  S_DB_NAME  : name of traits database record
#  S_CV_NAME  : name of traits cv record 
#-----------------------------------------------------------#
sub get_data_info {
  my $config = $_[0];
  
  # set database info
  my %data_info = ();
  $data_info{'DB_NAME'}   = $config->{'DB_NAME'};
  $data_info{'CV_NAME'}   = $config->{'CV_NAME'};
  $data_info{'S_CV_NAME'} = $config->{'S_CV_NAME'};
  $data_info{'S_DB_NAME'} = $config->{'S_DB_NAME'};
  
  return \%data_info;
}#get_data_info


#-----------------------------------------------------------------------------#
# get_log_time_stamp: return time string
#-----------------------------------------------------------------------------#
sub get_log_time_stamp {
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  return sprintf("%d-%02d-%02d_%02dh-%02dm", $year+1900, $mon+1, $mday, $hour, $min);
}#get_log_time_stamp


#-----------------------------------------------------------------------------#
# log time
#-----------------------------------------------------------------------------#
sub log_time {
  my ($msg) = @_;
  my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
  my $time_str = $pg_db->trim($msg).sprintf("%d-%02d-%02d_%02dh-%02dm-%02ds", $year+1900, $mon+1, $mday, $hour, $min, $sec)."\n";
  println($time_str, 'L');
}#log_time


#-----------------------------------------------------------------------------#
# open_excel_file: open excel file
#-----------------------------------------------------------------------------#
sub open_excel_file {
  my ($excel)= @_;
  
  # open file for reading excel file
  (-e $excel) or die "\n\tERROR: cannot open Excel file $excel for reading\n\n";
  my $oExcel = new Spreadsheet::ParseExcel;
  my $oBook = ($oExcel->Parse($excel));
  return $oBook;
}#open_excel_file


#-----------------------------------------------------------------------------#
# open_log_file: create log file
#-----------------------------------------------------------------------------#
sub open_log_files {
  my ($log_folder)= @_;
  
  # create a folder for log file
  if (not (-e $log_folder)) {
    mkdir($log_folder, 0777) 
      or die "\n\tcannot mkdir $log_folder:\n\t$!\n";
    println("\n\tcreate a folder ".$log_folder."\n\n",'L');
  }
  
  # create a sub-folder for log files
  my $jobname = basename($excel);
  my $log_folder_sub = $log_folder.'/'.get_log_time_stamp().'_'.$jobname;
  if (not (-e $log_folder_sub)) {
    mkdir($log_folder_sub, 0777) 
      or die "\n\tcannot mkdir $log_folder_sub:\n\t$!\n";
    println("\n\tcreate a folder ".$log_folder_sub."\n\n",'L');
  }
  
  # open log file
  my $log_name = 'trait_loader.log';
  open ($loghandle, ">$log_folder_sub/$log_name") 
    or die "\nCan't open log file: $log_folder_sub/$log_name: $!\n\n";
  
  return $log_folder_sub;
}#open_log_files


#-----------------------------------------------------------------------------#
# postprocess
#-----------------------------------------------------------------------------#
sub postprocess {
  my ($oBook, $start_time)= @_;
  
  # Log execution time
  my $run_time = time() - $start_time;
  log_time('Process ended at ');
  my $run_time_formatted = sec_to_time_str($run_time);
  println("Run time : $run_time_formatted\n\n",'L');

#TODO: some feedback about #'s of records to be inserted, though need not be 
#      exhaustive, just the major table corresponding to each worksheet

  # commit transaction
  print "\tCommit changes to database? (y or n) >";
  my $opt= <STDIN>;
  chomp($opt);
  if ($opt eq 'y') {
    $pg_db->execute_query_stmt('COMMIT;');
  }
  
  # close log files
  close(LOG);
  
  # disconnect database handler
  $pg_db->disconnect_db();
  
  print "\n\n\tProcess completed!\n\n";
}#postprocess


#-----------------------------------------------------------------------------#
# preprocess
# Read configuration file
#-----------------------------------------------------------------------------#
sub preprocess {
  
  # Read the configuration file
  my $config = readConfigFile();
  
  # open log file and get folder for logs for this run
  my $log_folder_sub = open_log_files($config->{'log_folder'});
  # keep sub log folder here for other modules to use:
  $config->{'log_folder_sub'} = $log_folder_sub;

  $pg_db = PG_Database->new($config);

  # start time
  my $start_time = time();
  log_time('Loading process started at ');

  # initialize init_helper module
  init_helper_module($pg_db);

  # connect to database
  $pg_db->connect_db();
  
  # get the source of data
  $data_info_ref = get_data_info($config);

  # set search_path to data schema(s)
  $pg_db->execute_query_stmt('SET SEARCH_PATH TO ' . $config->{'search_path'});

  # initiate transaction
  $pg_db->execute_query_stmt('BEGIN;');
  
  # initialize init_helper module
  init_helper_module($pg_db);
  
  # open input excel file
  my $oBook = open_excel_file($excel);
  
  # update data_info (db_id, cv_id and source of cv_id)
  get_cvs($data_info_ref, $config);
  
  # get module info
  my $loaders_ref = set_loader_info($data_info_ref, $config);
  
  # create publication reference hash
  my %pub_id = ();
  $pub_id_ref = \%pub_id;
  
  return ($start_time, $loaders_ref, $oBook);
}#preprocess


#-----------------------------------------------------------------------------#
# convert seconds to human readable time format
#-----------------------------------------------------------------------------#
sub sec_to_time_str {
  my ($run_time) = @_;
  
  my $time_str = int($run_time/(24*60*60)).'d ';
  $time_str   .= int(($run_time/(60*60))%24).'h ';
  $time_str   .= int(($run_time/60)%60).'m ';
  $time_str   .= int($run_time%60).'s';
  
  return $time_str;
}#sec_to_time_str


#-----------------------------------------------------------------------------#
# set_loader_info: get module information
#-----------------------------------------------------------------------------#
sub set_loader_info {
  my ($data_info_ref, $config) = @_;
  my %loaders = ();
  
  if ($config->{'contact'}) {
    $loaders{'contact'}          = {'MODULE' => 'contact',          'SHEET' => $config->{'contact'} };
  }
  if ($config->{'publication'}) {
    $loaders{'publication'}      = {'MODULE' => 'publication',      'SHEET' => $config->{'publication'} };
  }
  if ($config->{'site-environment'}) {
    $loaders{'site-environment'} = {'MODULE' => 'site-environment', 'SHEET' => $config->{'site-environment'} };
  }
  if ($config->{'dataset'}) {
    $loaders{'dataset'}          = {'MODULE' => 'dataset',          'SHEET' => $config->{'dataset'} };
  }
  if ($config->{'stock'}) {
    $loaders{'stock'}            = {'MODULE' => 'stock',            'SHEET' => $config->{'stock'} };
  }
  if ($config->{'mapset'}) {
    $loaders{'mapset'}           = {'MODULE' => 'mapset',           'SHEET' => $config->{'mapset'} };
  }
  if ($config->{'linkagegroup'}) {
    $loaders{'linkagegroup'}     = {'MODULE' => 'linkagegroup',     'SHEET' => $config->{'linkagegroup'} };
  }
  if ($config->{'marker'}) {
    $loaders{'marker'}           = {'MODULE' => 'marker',           'SHEET' => $config->{'marker'} };
  }
  if ($config->{'qtl'}) {
    $loaders{'qtl'}              = {'MODULE' => 'qtl',              'SHEET' => $config->{'qtl'} };
  }
  if ($config->{'qtltrait'}) {
    $loaders{'qtltrait'}         = {'MODULE' => 'qtltrait',         'SHEET' => $config->{'qtltrait'} };
  }
  if ($config->{'mapposition'}) {
    $loaders{'mapposition'}      = {'MODULE' => 'mapposition',      'SHEET' => $config->{'mapposition'} };
  }
  if ($config->{'image'}) {
    $loaders{'image'}            = {'MODULE' => 'image',            'SHEET' => $config->{'image'} };
  }

  return \%loaders;
}#set_loader_info