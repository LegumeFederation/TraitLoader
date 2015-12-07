###############################################################################
# Author      : 
# Name        : 
# Date        : 
# Description : verifier for 'contact' worksheet
###############################################################################

use strict;
use BerkeleyDB;
use Switch;

our $contact_identifer_ref;

#-----------------------------------------------------------------------------#
# verify_contact
#-----------------------------------------------------------------------------#
sub verify_contact {
  my ($pg_db, $oBook, $module_ref, $data_info_ref, $berkeley_dbh)= @_;
  
  my $error_count;
  my $warning_count;
  
  # process excel sheet
  my ($excel_ref, $cvterm_ref, $sp_col_refs, $error)
      = process_excel($oBook, $module_ref->{SHEET}, $data_info_ref, $berkeley_dbh);
  if ($error ne '') {
    println("\n$error\n\t[$module_ref->{SHEET}] Abort: process excel sheet...\n\n",'SE');
    return 0;
  }
  
  my ($column_name, $row_num, $berkeley_key, $berkeley_value);
  my $cursor = $berkeley_dbh->db_cursor();
  while ($cursor->c_get($berkeley_key, $berkeley_value, DB_NEXT) == 0) {
  #splitting the $berkeley_key which is in the format (sheetname:colname:rownum)
  my @details = split(/:/,$berkeley_key);
  $column_name = $details[1];    
  $row_num = $details[2];  
     
      switch($berkeley_key){
        
        case (/^[.*]:[name_code]:[.*]/){
          #RULE: name_code must be filled in.
          if (!$berkeley_value) {
            $error_count++;
            print "ERROR in record $row_num: The value in the column $column_name is missing \n";
          }#if
        }#case: name_code
        
        case (/^[.*]:[name]:[.*]/){
          #RULE: name must be filled in.
          if (!$berkeley_value) {
            $error_count++;
            print "ERROR in record $row_num: The value in the column $column_name is missing \n";
          }#if
          #RULE: Warn if name is already existing in contact
          if (get_contact($pg_db, $berkeley_value)) {
            $warning_count++;
            print "warning in row $row_num: a contact record with the ";
            print "name '$berkeley_value' already exists.\n";
          }#if
        }#case: name
        
        case (/^[.*]:[contact]:[.*]/) {
          $error_count++;
          print "ERROR in the record $row_num. The value in the column $column_name is missing \n";        
        }#case: contact
        
        case (/^[.*]:[contact_type]:[.*]/){
          #RULE: contact_type field must be filled-in
          if (!$berkeley_value) {
            $error_count++;
            print "ERROR in record $row_num: The value in the column $column_name is missing \n";
          }#if
          
          #RULE: contact_type must be in trait dictionary
          my $contact_type_id = get_cvterm_id($berkeley_value, $data_info_ref->{CV_ID});
          if (!$contact_type_id) {
            $error_count++;
            print "ERROR in record $row_num: No contact type $berkeley_value is in the trait dictionary.\n";
            print "      Permitted contact types include: " . join(', ', keys(get_contact_types($pg_db)));
            print "\n";
          }#if 
        }#case: contact_type
        
      }#switch 
  }#while - For each record of contact sheet

  if ($error_count == 0 && $warning_count > 0) {
    my $prompt = "There are $warning_count warnings in the contact worksheet. ";
    $prompt   .= "Do you want to continue loading? (y/n) ";
    exit if (get_user_response($prompt) != 'y');
  }
  elsif ($error_count > 0) {
    print "\nUnable to continue loading the contact worksheet because of ";
    print "$error_count error(s).\n\n";
  }

  return ($error_count == 0);
}#verify_contact
1;
__END__