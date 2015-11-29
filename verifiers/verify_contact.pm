###############################################################################
# Author      : 
# Name        : 
# Date        : 
# Description : verifier for 'contact' worksheet
###############################################################################

use strict;

our $contact_identifer_ref;

#-----------------------------------------------------------------------------#
# verify_contact
#-----------------------------------------------------------------------------#
sub verify_contact {
  my ($pg_db, $oBook, $module_ref, $data_info_ref)= @_;
  
  my $error_count;
  my $warning_count;
  
  # process excel sheet
  my ($excel_ref, $cvterm_ref, $sp_col_refs, $error)
      = process_excel($oBook, $module_ref->{SHEET}, $data_info_ref);
  if ($error ne '') {
    println("\n$error\n\t[$module_ref->{SHEET}] Abort: process excel sheet...\n\n",'SE');
    return 0;
  }

  foreach my $ctr (sort { $a <=> $b } keys %{$excel_ref}) {
  
    # RULE: fields name_code, name, and contact must be filled in
    # -----
    if (!$excel_ref->{$ctr}{name_code}) {
      $error_count++;
      print "ERROR in row $excel_ref->{$ctr}{row}: missing required 'name_code' field in record $ctr\n";
    }
    if (!$excel_ref->{$ctr}{name}) {
      $error_count++;
      print "ERROR in row $excel_ref->{$ctr}{row}: missing required 'name' field in record $ctr\n";
    }
    if (!$excel_ref->{$ctr}{contact_type}) {
      $error_count++;
      print "ERROR in row $excel_ref->{$ctr}{row}: missing required 'contact_type' field in record $ctr\n";
    }
    
    # RULE: contact_type must be in trait dictionary
    # -----
    my $contact_type = $excel_ref->{$ctr}{contact_type};
    my $contact_type_id = get_cvterm_id($contact_type, $data_info_ref->{CV_ID});
    if (!$contact_type_id) {
      $error_count++;
      print "ERROR in row $excel_ref->{$ctr}{row}: no contact type '$contact_type' is in the trait dictionary.\n";
      print "      Permitted contact types include: " . join(', ', keys(get_contact_types($pg_db)));
      print "\n";
    }

    # RULE: warn if name/name_code already in contact 
    # -----
    if (get_contact($pg_db, $excel_ref->{$ctr}{name})) {
      $warning_count++;
      print "warning in row $excel_ref->{$ctr}{row}: a contact record with the ";
      print "name '$excel_ref->{$ctr}{name}' already exists.\n";
    }
  }#each contact record
  
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