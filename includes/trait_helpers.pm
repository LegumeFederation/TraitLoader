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
# check_cvterm : check for cvterm in cvterm table
#-----------------------------------------------------------------------------#
sub check_cvterm {
  my ($cvterm, $cv_id)= @_;
  
  return q{} if (!$cvterm);
    
  my $cvterm_lc = lc($pg_db->trim($cvterm));
  my $sql;

  # check for cvterm
  if (defined $cv_id) {
    $sql = "
      SELECT cvterm_id FROM cvterm 
      WHERE cv_id = '$cv_id' AND LOWER(name) = '$cvterm_lc'";
  }
  else {
    $sql = "
      SELECT cvterm_id FROM cvterm 
      WHERE LOWER(name) = '$cvterm_lc' ORDER BY cvterm_id";
  }
  
  my $cvterm_id = $pg_db->query_field($sql);
  if (!$cvterm_id) {
    my $msg = "cvterm_id for (cv_id, cvterm)=($cv_id, $cvterm) does not ";
    $msg   .= "exist in cvterm table";
    println("\n\t$msg\n",'SL');
    print "\n\t$msg\n";
    exit;
  }
  
  return $cvterm_id;
}#check_cvterm


#-----------------------------------------------------------------------------#
# check_cvterm_id
#-----------------------------------------------------------------------------#
sub check_cvterm_id {
  my $cvterm_ref= shift;
  
  # find missing cvterm_id
  my $error= '';
  foreach my $id (keys %{$cvterm_ref}) {
    $error .= "$id " if ($cvterm_ref->{$id} eq '');
  }
  return $error;
}#check_cvterm_id


#-----------------------------------------------------------------------------#
# check_empty
#-----------------------------------------------------------------------------#
sub check_empty {
  my ($func_name, $attr_ref)= @_;
  
  # check required field
  my ($flag, $msg, $list_attr, $list_val) = (0, '', '', '');
  foreach my $attr (keys %{$attr_ref}) {
    $list_attr .= " $attr,";
    $list_val  .= " '$attr_ref->{$attr}',";
    if ($pg_db->trim($attr_ref->{$attr} eq '')) {
      $msg .= "$attr is empty ";
      $flag = 1;
    }
  }
  # print warning message
  if ($flag) {
    println("\tcheck_empty [warn] $func_name skipped since $msg\n\t\t>($list_attr) = ($list_val)\n",'W');
  }
  
  return $flag;
}#check_empty


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
}#get_columns


#-----------------------------------------------------------------------------#
# get_cv_id
#-----------------------------------------------------------------------------#
sub get_cv_id {
  my ($cv_name) = @_;
  $cv_name = $pg_db->trim($cv_name);
  
  my $sql = "SELECT cv_id FROM cv WHERE LOWER(name) = LOWER('$cv_name')";
  return $pg_db->query_field($sql);
}#get_cv_id


#-----------------------------------------------------------------------------#
# get_cvterm_id
#-----------------------------------------------------------------------------#
sub get_cvterm_id {
  my ($name, $cv_id) = @_;
  
  my $sql = "
    SELECT cvterm_id FROM cvterm 
    WHERE cv_id = '$cv_id' AND LOWER(name) = LOWER('$name')";
  return $pg_db->query_field($sql);
}#get_cvterm_id


#-----------------------------------------------------------------------------#
# get_contact
#-----------------------------------------------------------------------------#
sub get_contact {
  my ($pg_db, $name) = @_;
  my $sql = "
    SELECT contact_id FROM contact WHERE name = '$name'";

  return $pg_db->query_field($sql);
}#get_contact


#-----------------------------------------------------------------------------#
# get_contact_types
#-----------------------------------------------------------------------------#
sub get_contact_types {
  my $pg_db = $_[0];
  my $sql = "
    SELECT name FROM cvterm 
    WHERE definition LIKE 'Contact type%'
          AND cv_id=(SELECT cv_id FROM cv WHERE name='tripal_trait_dictionary')";

  return $pg_db->get_all_rows('name', $sql);
}#get_contact_types


#-----------------------------------------------------------------------------#
# get_db_id
#-----------------------------------------------------------------------------#
sub get_db_id {
  my ($db_name) = @_;
  return $pg_db->query_field("SELECT db_id FROM db WHERE LOWER(name) = LOWER('$db_name')");
}


#-----------------------------------------------------------------------------#
# getCVtermIDs
#-----------------------------------------------------------------------------#
sub getCVtermIDs {
  my ($loader, $module_ref, $data_info_ref) = @_;
  my (%cvterm_id, $error);

  if ($loader eq 'contact') {
    $cvterm_id{name_code}          = check_cvterm('name_code',          $data_info_ref->{CV_ID});
    $cvterm_id{name}               = check_cvterm('name',               $data_info_ref->{CV_ID});
    $cvterm_id{first_name}         = check_cvterm('first_name',         $data_info_ref->{CV_ID});
    $cvterm_id{last_name}          = check_cvterm('last_name',          $data_info_ref->{CV_ID});
    $cvterm_id{title}              = check_cvterm('title',              $data_info_ref->{CV_ID});
    $cvterm_id{alias}              = check_cvterm('alias',              $data_info_ref->{CV_ID});
    $cvterm_id{contact_type}       = check_cvterm('contact_type',       $data_info_ref->{CV_ID});
    $cvterm_id{affiliation}        = check_cvterm('affiliation',        $data_info_ref->{CV_ID});
    $cvterm_id{lab}                = check_cvterm('lab',                $data_info_ref->{CV_ID});
    $cvterm_id{address}            = check_cvterm('address',            $data_info_ref->{CV_ID});
    $cvterm_id{country}            = check_cvterm('country',            $data_info_ref->{CV_ID});
    $cvterm_id{email}              = check_cvterm('email',              $data_info_ref->{CV_ID});
    $cvterm_id{phone}              = check_cvterm('phone',              $data_info_ref->{CV_ID});
    $cvterm_id{fax}                = check_cvterm('fax',                $data_info_ref->{CV_ID});
    $cvterm_id{url}                = check_cvterm('url',                $data_info_ref->{CV_ID});
    $cvterm_id{research_interests} = check_cvterm('research_interests', $data_info_ref->{CV_ID});
    $cvterm_id{last_update}        = check_cvterm('last_update',        $data_info_ref->{CV_ID});
    $cvterm_id{comments}           = check_cvterm('comments',           $data_info_ref->{CV_ID});
    $cvterm_id{curator_comments}   = check_cvterm('curator_comments',   $data_info_ref->{CV_ID});
    
    $error = check_cvterm_id(\%cvterm_id);
  }#contact
  
  else {
    $error = "Don't know what cvterms are used for the $loader loader.";
  }
  
  if ($error) {
    println("\n\t[$module_ref->{SHEET}] Abort: cvterm_id missing : $error\n\n",'SE');
    return;
  }
  else {
    return \%cvterm_id;
  }
}#getCVtermIDs


#-----------------------------------------------------------------------------#
# get_user_response
#-----------------------------------------------------------------------------#
sub get_user_response {
  my $prompt = $_[0];
  
  print $prompt;
  my $opt= <STDIN>;
  chomp($opt);
  
  return lc($opt);
}#get_user_response


#-----------------------------------------------------------------------------#
# insert_into_contact
#-----------------------------------------------------------------------------#
sub insert_into_contact {
  my ($type_id, $name, $description)= @_;
  $name = $pg_db->trim($name);
  
  my $update = 0;
  
  # check required variables
  return (0, 0) if (check_empty('insert_into_contact', 
                                 {name => $name, type_id => $type_id}));
  
  # check if record exists
  my $sql = "
    SELECT contact_id, t.name AS type, description 
    FROM contact c
      INNER JOIN cvterm t ON t.cvterm_id=c.type_id 
    WHERE LOWER(c.name) = LOWER('$name')";
  my $row = $pg_db->query_fields($sql);
  my $contact_id = ($row->[0]) ? $row->[0] : 0;

  my %record_new_table;
  $record_new_table{name}        = $name;
  $record_new_table{type_id}     = $type_id;
  $record_new_table{description} = $description;

  if (!$contact_id) {
    $sql = "SELECT NEXTVAL('contact_contact_id_seq')";
    $contact_id = $pg_db->query_field($sql);
    $record_new_table{contact_id}  = $contact_id;
    
    insert_new_record('contact', \%record_new_table);
  }
  else {
    # record already exists. Overwrite?
    my $prompt = "\nThe record for '$name' already exists ";
    $prompt   .= "with type $row->[1]. Overwrite? (y/n) ";
    my $ch = get_user_response($prompt);
    if ($ch eq 'y') {
      $update = 1;
      update_record('contact', \%record_new_table, 'contact_id', $contact_id);
    }
  }
  
  return ($contact_id, $update);
}#insert_into_contact


#-----------------------------------------------------------------------------#
# insert_into_contactprop
#-----------------------------------------------------------------------------#
sub insert_into_contactprop {
  my ($contact_id, $type_id, $value, $update, $rank)= @_;
  $rank= '0' if (!defined $rank);
  
  # check required variables
  return (0, 0) if(check_empty('insert_into_contactprop', 
                  {contact_id => $contact_id, type_id => $type_id, value => $value }));
  
  my %record_new_table;
  $record_new_table{contact_id} = $contact_id;
  $record_new_table{value}      = $value;
  $record_new_table{type_id}    = $type_id;
  $record_new_table{rank}       = $rank;
  
  # insert/update a record
  my $sql = "
    SELECT contactprop_id 
    FROM contactprop 
    WHERE contact_id = '$contact_id' AND type_id = '$type_id'";
  my $contactprop_id = $pg_db->query_field($sql);
  if ($contactprop_id eq '') {
    my $sql = "SELECT NEXTVAL('contactprop_contactprop_id_seq')";
    $contactprop_id = $pg_db->query_field($sql);
    $record_new_table{contactprop_id} = $contactprop_id;
    insert_new_record('contactprop', \%record_new_table);
  }
  elsif ($update) {
    update_record('contactprop', \%record_new_table, 'contactprop_id', $contactprop_id);
  }
  else {
    println("\t[dup] (contact_id, type_id, value) = ($contact_id, $type_id, $value) exists in contactprop table\n",'D');
  }
  
  return $contactprop_id;
}#insert_into_contactprop


#-----------------------------------------------------------------------------#
# insert_new_records
#-----------------------------------------------------------------------------#
sub insert_new_record {
  my ($table_name, $record_ref)= @_;
  
  println("\n\t-----[new: $table_name]-----------------------\n",'N');
#  foreach my $attr (keys %{$record_ref}) {
#    if ($attr eq 'type_id' || $attr eq 'cvterm_id') {
#      my $sql = "SELECT name FROM cvterm WHERE cvterm_id = '$record_ref->{$attr}'";
#      my $name = $pg_db->query_field($sql);
#      println(sprintf("\t%-30s : %s (%s)\n",$attr, $record_ref->{$attr}, $name),'N');
#    }
#    else {
#      println(sprintf("\t%-30s : %s\n",$attr, $record_ref->{$attr}),'N');
#    }
#  }
  
  # insert a record
  $pg_db->insert_new_record($table_name, $record_ref);
  println("\t(record inserted)\n",'N');
  println("\t----------------------------------------\n",'N');
}#insert_new_record


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
    
    # record worksheet row number to add user data debugging
    $record_excel{$ctr}{row} = $row + 1;
    
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


#-----------------------------------------------------------------------------#
# update_record
#-----------------------------------------------------------------------------#
sub update_record {
  my ($table_name, $record_ref, $pr_field, $pr_value)= @_;
print "update record where $pr_field = $pr_value\n";
  
  println("\n\t-----[update: $table_name]-----------------------\n",'N');
#  foreach my $attr (keys %{$record_ref}) {
#    if ($attr eq 'type_id' || $attr eq 'cvterm_id') {
#      my $sql = "SELECT name FROM cvterm WHERE cvterm_id = '$record_ref->{$attr}'";
#      my $name = $pg_db->query_field($sql);
#      println(sprintf("\t%-30s : %s (%s)\n",$attr, $record_ref->{$attr}, $name),'N');
#    }
#    else {
#      println(sprintf("\t%-30s : %s\n",$attr, $record_ref->{$attr}),'N');
#    }
#  }
  
  # insert a record
  $pg_db->update_record($table_name, $record_ref, $pr_field, $pr_value);
  println("\t(record updated where $pr_field=$pr_value)\n",'N');
  println("\t------------------------------------------\n",'N');
}#update_record



1;
__END__
