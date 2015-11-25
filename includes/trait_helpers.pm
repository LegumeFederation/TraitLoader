#!/usr/bin/perl

##############################################################################
# Author       : Ethy Cannon 
#                NOTE: developed from scripts written by Taein Lee 
#                      in the Main Lab, Washington State University.
# Target       : Generic loader for QTL/Map/Marker data
# Name         : trait_helpers.pm
# Date         : November, 2015
# Description  : Utility scripts for perl trail loaders
##############################################################################

use strict;
use Data::Dumper;

#TODO: may not want this; seems to only be used to count records inserted
#my %tables;
our $pg_db;
our $data_info_ref;

#-----------------------------------------------------------------------------#
# init_helper_module
#-----------------------------------------------------------------------------#
sub init_helper_module {
  my ($db_ref)= @_;
  
  # set database handler
  $pg_db = $db_ref;
}#init_helper_module


#-----------------------------------------------------------------------------#
# get_columns
#-----------------------------------------------------------------------------#
sub get_columns {
	my ($oBook, $sheet_name)= @_;
	my %columns = ();
	
	if (!$sheet_name || $sheet_name eq '') {
	  println("No sheet name provided.\n");
	  return %columns;
	}
	
	# extract header columns
	my $sheet= $oBook->Worksheet($sheet_name);
	
	for (my $col= $sheet->{MinCol}; defined $sheet->{MaxCol} && $col <= $sheet->{MaxCol}; $col++) {
		my $cell= $sheet->{Cells}[0][$col];
		
		# last column if cell does not have value
		goto LAST_COL if (!defined($cell));
		my $column= lc($pg_db->trim($cell->Value()));
		goto LAST_COL if ($column eq '');
		
		# assign column info
		if ($column =~ /^\*/) {
			$column= substr($column, 1);
			$columns{$column}{TYPE}= 'REQ';
			$columns{$column}{COL}= $col;
		}
		elsif ($column =~ /^#/) {
			$column= substr($column, 1);
			$columns{$column}{TYPE}= 'S_CVTERM';
			$columns{$column}{COL}= $col;
		}
		elsif ($column =~ /^\$/) {
			$column= substr($column, 1);
			$columns{$column}{TYPE}= 'S_SP_COL';
			$columns{$column}{COL}= $col;
		}
		else {
			$columns{$column}{TYPE}= 'DATA';
			$columns{$column}{COL}= $col;
		}
	}
LAST_COL:
	return \%columns;
}


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


#TODO: may not want this; seems to only be used to count new records
#-----------------------------------------------------------------------------#
# module_pre_process
#-----------------------------------------------------------------------------#
#sub module_pre_process {
#  my ($module)= @_;
#  my %num_record= ();
#  
#  println("\n\t========================================\n\n",'SLDN');
#  println("\n\tProcessing module : $module\n",'SLDN');
#  
#  # get number of records in tables
#  my $table_ref= $tables{$module};
#  foreach my $table (@{$table_ref}) {
#    $num_record{$table}{BEFORE}= $pg_db->query_field("SELECT COUNT(*) FROM $table");
#  }
#
#  return \%num_record;
#}


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
    # print to screen if no code specified
    print "$string\n";
  }
}


#-----------------------------------------------------------------------------#
# process_excel
# 1. check required fields
# 2. check non-data (cvterms)
#    add a new cvterm if not exists in table
#-----------------------------------------------------------------------------#
sub process_excel {
  my ($oBook, $sheet_name, $data_info_ref)= @_;
  
  my %record_excel  = ();
  my %cvterm_excel  = ();
  my %sp_cols_excel = ();
  
  # get header column info.
  my $columns_ref = get_columns($oBook, $sheet_name);
  my $num_cols = scalar keys %{$columns_ref};
  
  # 1. check required fields
  my $sheet = $oBook->Worksheet($sheet_name);
  my $ctr = 0;
  my ($error_msg, $msg) = ('','');
  my $num_rows = 0;
  for (my $row=$sheet->{MinRow}+1; defined $sheet->{MaxRow} && $row<=$sheet->{MaxRow}; $row++) {
    my $end_of_data = '';
    my %records = ();
    my %cvterms = ();
    my %sp_cols = ();
    
    # check if it is end of data
    foreach my $column (keys %{$columns_ref}) {
      # get cell value
      my $col       = $columns_ref->{$column}{COL};
      my $cell      = $sheet->{Cells}[$row][$col];
      my $value     = (defined $cell) ? $pg_db->trim_quote($cell->Value) : '';
      $end_of_data .= $value;
    }
    
    last if ($end_of_data eq '');
    ++$num_rows;
    
    # check data
    foreach my $column (keys %{$columns_ref}) {
      # get cell value
      my $col   = $columns_ref->{$column}{COL};
      my $cell  = $sheet->{Cells}[$row][$col];
      my $value = (defined $cell) ? $pg_db->trim_quote($cell->Value) : '';
      
      # store cvterm column
      if ($columns_ref->{$column}{TYPE} eq 'S_CVTERM') {
        $cvterms{lc($data_info_ref->{S_CV_NAME}).'_'.$column}= $value;
      }
      elsif ($columns_ref->{$column}{TYPE} eq 'S_SP_COL') {
        $sp_cols{lc($column)}= $value;
      }
      # store data column
      else {
        if ($columns_ref->{$column}{TYPE} eq 'REQ' && ($value eq '')) {
          $msg.= "\trequired field is missing (row, col [$column]) = ($row, $col) in $sheet_name\n";
        }
        $records{$column}= $value;
      }
    }
    
    $error_msg.= $msg;
    $msg= '';
    
    # copy back to record_excel, cvterm_excel and sp_col_excel
    foreach my $record (keys %records) {
      $record_excel{$ctr}{$record}= $records{$record};
    }
    foreach my $cvterm (keys %cvterms) {
      $cvterm_excel{$ctr}{$cvterm}= $cvterms{$cvterm};
    }
    foreach my $sp_col (keys %sp_cols) {
      $sp_cols_excel{$ctr}{$sp_col}= $sp_cols{$sp_col};
    }
    $ctr++;
  }
  println("\n\t$sheet_name has $num_rows rows with $num_cols columns\n\n",'L');
  
  # 2. check cvterms (non-MAIN cvterm)
  my $add_cvterm= (defined $data_info_ref) ? 1 : 0;
  if ($error_msg eq '' && $add_cvterm) {
    for my $s_cvterm (keys %{$cvterm_excel{0}}) {
      my $cvterm_id= check_cvterm($s_cvterm, $data_info_ref->{S_CV_ID});
      my $dup_cvterm_id = '';
      
      # insert a new $cvterm if it is not exists
      if ($cvterm_id eq '') {
        println("\t$s_cvterm does not exists in cvterm table\n",'L');
        my ($dbxref_id, $dup_dbxref_id) 
              = insert_into_dbxref($data_info_ref->{DB_ID}, $s_cvterm, 'phenotype');
        ($cvterm_id, $dup_cvterm_id) 
              = insert_into_cvterm($dbxref_id, $data_info_ref->{S_CV_ID}, $s_cvterm, 'phenotype');
        println("\t$s_cvterm inserted in cvterm/dbxref tables\n",'SL');
      }
    }
  }
  
  return (\%record_excel, \%cvterm_excel, \%sp_cols_excel, $error_msg)
}#process_excel


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
